require "rails/generators"
require "rails/generators/active_record"

module Aeternitas
  # Installs Aeternitas in a rails app.
  class InstallGenerator < ::Rails::Generators::Base
    include Rails::Generators::Migration

    source_root File.expand_path("../templates", __FILE__)

    desc "Generates (but does not run) a migration to add all tables needed by Aeternitas." \
         "  Also generates an initializer file for configuring Aeternitas"

    def create_migration_file
      migration_dir = File.expand_path("db/migrate")
      if self.class.migration_exists?(migration_dir, "add_aeternitas")
        ::Kernel.warn "Migration 'add_aeternitas' already exists. Skipping."
      else
        migration_template("add_aeternitas.rb.erb", "db/migrate/add_aeternitas.rb")
      end
    end

    def copy_initializer
      copy_file("initializer.rb", "config/initializers/aeternitas.rb")
    end

    def reminder
      say "\nDon't forget to regularly run 'Aeternitas.enqueue_due_pollables', e.g., using 'whenever'", :red
      say "You should also schedule maintenance jobs:\n", :yellow
      say "To clean up old metrics (if metrics are enabled):\n"
      say "    Aeternitas::CleanupOldMetricsJob.perform_later\n", :white
      say "To clean up stale locks from crashed workers:\n"
      say "    Aeternitas::CleanupStaleLocksJob.perform_later\n", :white
      say "Schedule these to run periodically, for example, once a week.\n"
    end

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end
  end
end
