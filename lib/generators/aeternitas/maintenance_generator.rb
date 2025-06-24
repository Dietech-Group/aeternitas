require "rails/generators"

module Aeternitas
  # Installs a sample maintenance rake task in a rails app.
  class MaintenanceGenerator < ::Rails::Generators::Base
    source_root File.expand_path("../templates", __FILE__)

    desc "Generates a sample rake file for cleaning up stale Aeternitas data."

    def copy_rake_file
      copy_file("maintenance.rake.erb", "lib/tasks/aeternitas_maintenance.rake")
    end

    def reminder
      say "\nSample maintenance tasks have been generated in 'lib/tasks/aeternitas_maintenance.rake'.", :green
      say "Review the file, uncomment the tasks you need, and schedule them to run periodically.", :green
      say "For example, using 'whenever' in your 'schedule.rb':", :yellow
      say "  every 1.day, at: '3:00 am' do", :yellow
      say "    rake 'aeternitas:maintenance:cleanup_all'", :yellow
      say "  end", :yellow
    end
  end
end
