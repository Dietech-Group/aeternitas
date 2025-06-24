$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "active_record"
require "active_job"
require "active_support/testing/time_helpers"
require "aeternitas"
require "database_cleaner"

# Configure ActiveJob test adapter
ActiveJob::Base.queue_adapter = :test

# Use a file-based database for tests that use threads.
FileUtils.mkdir_p "db"
ActiveRecord::Base.establish_connection adapter: "sqlite3", database: "db/test.sqlite3"
load File.dirname(__FILE__) + "/schema.rb"
require File.dirname(__FILE__) + "/pollables.rb"

# configure aeternitas
Aeternitas.configure do |conf|
  conf.storage_adapter_config = {
    directory: "/tmp/aeternitas_tests/"
  }
end

DatabaseCleaner.strategy = :transaction

RSpec.configure do |config|
  config.order = :random # Tests should not depend on each other

  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::TimeHelpers

  config.before(:suite) do
    # Clean once before suite using schema.rb definitions with force: true
    DatabaseCleaner.clean_with :truncation
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  config.around(:each, tmpFiles: true) do |example|
    example.run
  ensure
    FileUtils.rm_rf(Aeternitas.config.storage_adapter_config[:directory])
  end

  # Clear jobs before each test example
  config.before(:each) do
    clear_enqueued_jobs
    clear_performed_jobs
  end
end
