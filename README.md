# Æternitas

[![Tests](https://github.com/Dietech-Group/aeternitas/actions/workflows/tests.yml/badge.svg)](https://github.com/Dietech-Group/aeternitas/actions/workflows/tests.yml)
[![Lint](https://github.com/Dietech-Group/aeternitas/actions/workflows/lint.yml/badge.svg)](https://github.com/Dietech-Group/aeternitas/actions/workflows/lint.yml)

A Ruby gem for continuous source retrieval and data integration.

Æternitas provides means to regularly "poll" resources (i.e. a website, twitter feed or API) and to permanently store the retrieved results.
By default, it avoids putting too much load on external servers and stores raw results as compressed files on disk.
 Aeternitas can be configured to a wide variety of polling strategies (e.g. frequencies, cooldown periods, error handling, deactivation on failure).

Æternitas is meant to be included in a Rails application and uses a pure ActiveJob and ActiveRecord backend.
 All metadata, locks, and metrics are stored in your application's database, while raw source data is stored as compressed files on disk by default.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'aeternitas'
```

And then execute:

```bash
$ bundle install
$ rails generate aeternitas:install
$ rails db:migrate
```

This will install the gem, generate the necessary database tables, and create a configuration initializer.

### Maintenance

Æternitas creates lock and metric records in your database. To prevent this data from growing indefinitely, you should schedule periodic cleanup jobs. The two key maintenance jobs are:

- **`Aeternitas::CleanupStaleLocksJob`**: Removes old, expired lock records from crashed workers.
- **`Aeternitas::CleanupOldMetricsJob`**: Prunes metric data older than the configured `metric_retention_period`.

You should schedule these jobs to run periodically (e.g. weekly).

## Quickstart

Let's say you want to monitor several websites for the usage of a keyword, e.g. 'aeternitas'. First, create your model:

```bash
$ rails generate model Website url:string keyword_count:integer
```

Then, include `Aeternitas::Pollable` in your model and define your polling logic.

```ruby
class Website < ApplicationRecord
  include Aeternitas::Pollable

  polling_options do
    polling_frequency :weekly
  end

  def poll
    page_content = Net::HTTP.get(URI.parse(self.url))
    add_source(page_content) # Store the retrieved page content permanently
    count = page_content.scan('aeternitas').size
    update(keyword_count: count)
  end
end
```

The `poll` method is called each time Æternitas processes the job for this resource. In our example, this would be once a week.

 To start the polling process, you need to regularly run `Aeternitas.enqueue_due_pollables` and have an ActiveJob backend (like SolidQueue, GoodJob, etc.) running to process the jobs.

In most cases it makes sense to store polling results as sources to allow further work to be done in separate jobs. In above example we already added the `page_content` as a source to the website with `add_source`.
Aeternitas only stores a new source if the source's fingerprint (MD5 Hash of the content) does not exist yet. If we wanted to process the word count in a separate job the following implementation would allow to do so:

```ruby
# app/models/website.rb
class Website < ApplicationRecord
  include Aeternitas::Pollable

  polling_options do
    polling_frequency :weekly
  end

  def poll
    page_content = Net::HTTP.get(URI.parse(self.url))
    new_source = add_source(page_content) # returns nil if source already exists
    CountKeywordJob.perform_later(new_source.id) if new_source
  end
end

# app/jobs/count_keyword_job.rb
class CountKeywordJob < ApplicationJob
  queue_as :default

  def perform(source_id)
    source = Aeternitas::Source.find(source_id)
    page_content = source.raw_content
    keyword_count = page_content.scan('aeternitas').size
    website = source.pollable
    website.update(keyword_count: keyword_count)
  end
end
```

## Configuration

### Global Configuration

Global settings can be configured in `config/initializers/aeternitas.rb`.

#### Metrics
You can enable or disable metrics collection. By default, metrics are disabled.

```ruby
Aeternitas.configure do |config|
  # Set to true to enable logging metrics to the database.
  config.metrics_enabled = true

  # Configure how long to keep metric data.
  config.metric_retention_period = 180.days
end
```

#### Storage Adapter
By default, Æternitas stores source files as compressed files on disk. You can change this behavior by implementing a custom storage adapter. For an example you can have a look at `Aeternitas::StorageAdapter::File`.

```ruby
Aeternitas.configure do |config|
  # To change the storage directory for the default File adapter:
  config.storage_adapter_config = {
    directory: File.join(Rails.root, 'public', 'sources')
  }

  # To use a custom adapter:
  config.storage_adapter = Aeternitas::StorageAdapter::MyCustomAdapter
end
```

### Pollable Configuration

Pollables can be configured on a per-model basis using the `polling_options` block.

#### polling_frequency
_Default: :daily_

This option controls how often a pollable is polled and can be configured in two different ways.
Either use one of the presets specified in `Aeternitas::PollingFrequency` by specifying the presets name as a symbol:

```ruby
polling_options do
  polling_frequency :weekly
end
```

Or, if you want to specify a more complex polling schema you can do so by using a custom lambda for dynamic frequency:

```ruby
polling_options do
  # set frequency depending elements age (+ 1 month for every 3 months)
  polling_frequency ->(context) { 1.month.from_now + (Time.now - context.created_at).to_i / 3.months * 1.month }
end
```

#### before_polling / after_polling
_Default: []_

Specify methods to run before each poll or after each successful poll. You can either specify a method name or a lambda:

```ruby
polling_options do
  before_polling :log_start
  after_polling ->(pollable) { puts "Finished polling #{pollable.id}" }
end
```

#### deactivate_on / ignore_error
_Default: []_

Define custom error handling rules.

 `deactivate_on` will stop polling a resource permanently if a specified error occurs. This can be useful if the error implied that the resource does not exist anymore.
 
 `ignore_error` will wrap the error within `Aeternitas::Errors::Ignored` which is then raised instead. This can be useful for filtering in exception tracking services like Airbrake.

```ruby
polling_options do
  deactivate_on Twitter::Error::NotFound
  ignore_error Twitter::Error::ServiceUnavailable
end
```

#### sleep_on_guard_locked
_Default: false_

Controls behavior when a guard lock cannot be acquired.
- **`false`:** The job will be retried with a smart, staggered backoff delay to prevent a "thundering herd." This is the recommended and most scalable option.
- **`true`:** The job will cause the ActiveJob worker thread to `sleep` until the lock is expected to be free, blocking that thread from processing other jobs. This is an aggressive strategy and should *only* be used in specific cases where you intend to pause a dedicated worker.

#### queue
_Default: 'polling'_

This option specifies the ActiveJob queue for the poll job.

#### guard_key
_Default: obj.class.name.to_s_

Defines the key used for resource locking. By default, all instances of a model share the same lock. The default is to lock on pollable class level, but you can also provide a block for more granular locking (e.g. per-instance or per-API-host):

```ruby
polling_options do
  # Lock based on the instance's URL host
  guard_key ->(website) { URI.parse(website.url).host }
end
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Testing

Æternitas provides a test mode to help write tests. When enabled, all cooldowns, retry delays, and sleep durations are set to zero. This prevents your test suite from having to wait for scheduled delays.

To enable test mode for a specific block of code, use the `Aeternitas::Test.test_mode` helper:

```ruby
Aeternitas::Test.test_mode do
  # ...
end
```

This ensures that test mode is enabled only for the duration of the block and is automatically disabled afterward.

## Contributing

Bug reports and spec backed pull requests are welcome on GitHub at https://github.com/Dietech-Group/aeternitas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## History

This gem was originally developed under [FHG-IMW/aeternitas](https://github.com/FHG-IMW/aeternitas) and named "æternitas - A ruby gem for continuous source retrieval and data integration". It's core was based upon Sidekiq and Redis which both were removed as dependencies for this gem.
