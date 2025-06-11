# Æternitas - Version 2

This is going to become version 2 of aeternitas. The goals are:

1. Remove dependency on Sidekiq and Redis
2. Reduce functionality to a core which allows easier usage


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and spec backed pull requests are welcome on GitHub at https://github.com/Dietech-Group/aeternitas. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

## History

This gem was originally developed under [FHG-IMW/aeternitas](https://github.com/FHG-IMW/aeternitas) and named "æternitas - A ruby gem for continuous source retrieval and data integration". It's core was based upon Sidekiq and Redis which both were removed as dependencies for this gem.
