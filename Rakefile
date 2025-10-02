require "bundler/setup"

# Load environment variables from .env file
require "dotenv/load" if File.exist?(".env")

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"
load "rails/tasks/statistics.rake"

require "bundler/gem_tasks"

# Test tasks
namespace :test do
  desc "Run unit tests (models, helpers, services, instrumentation)"
  task :unit do
    sh "rails test test/models test/helpers test/services test/support test/instrumentation"
  end

  desc "Run functional tests (controllers)"
  task :functional do
    sh "rails test test/controllers"
  end

  desc "Run integration tests"
  task :integration do
    sh "rails test test/integration test/system"
  end

  desc "Run all tests"
  task :all do
    sh "rails test test/models test/controllers test/helpers test/services test/support test/instrumentation test/integration test/system"
  end

  desc "Reset all databases for local matrix testing"
  task :reset_databases do
    databases = ["sqlite3", "postgresql", "mysql2"]

    puts "\n" + "=" * 80
    puts "🗄️  Resetting databases for matrix testing"
    puts "=" * 80

    databases.each do |database|
      puts "\n🔄 Resetting #{database.upcase} database..."

      begin
        # Use .env file for database credentials, just set DB type
        sh "DB=#{database} FORCE_DB_CONFIG=true rails db:drop db:create"

        # Remove schema.rb to prevent Rails version conflicts
        schema_file = "test/dummy/db/schema.rb"
        if File.exist?(schema_file)
          File.delete(schema_file)
          puts "   Removed schema.rb (will be regenerated)"
        end

        puts "✅ #{database.upcase} database reset successfully"

      rescue => e
        puts "❌ Failed to reset #{database.upcase} database: #{e.message}"
        puts "   Make sure #{database} is installed and running"
        puts "   Check your .env file for correct #{database} credentials"
      end
    end

    puts "\n" + "=" * 80
    puts "🏁 Database Reset Complete"
    puts "You can now run: rake test:matrix"
    puts "=" * 80
  end

  desc "Run tests across all database and Rails version combinations (local only - CI uses sqlite3 + postgresql)"
  task :matrix do
    databases = [ "sqlite3", "postgresql", "mysql2" ]
    rails_versions = [ "rails-7-2", "rails-8-0" ]

    failed_combinations = []

    databases.each do |database|
      rails_versions.each do |rails_version|
        puts "\n" + "=" * 80
        puts "🧪 Local Testing: #{database.upcase} + #{rails_version.upcase}"
        puts "(CI only tests SQLite3 + PostgreSQL for reliability)"
        puts "=" * 80

        begin
          gemfile = "gemfiles/#{rails_version.gsub('-', '_')}.gemfile"

          # Use .env file for database credentials, just set required variables
          # Use rake test:all (custom task) instead of rails test:all (includes generators)
          sh "DB=#{database} BUNDLE_GEMFILE=#{gemfile} FORCE_DB_CONFIG=true bundle exec rake test:all"

          puts "✅ PASSED: #{database} + #{rails_version}"

        rescue => e
          puts "❌ FAILED: #{database} + #{rails_version}"
          puts "Error: #{e.message}"
          failed_combinations << "#{database} + #{rails_version}"
        end
      end
    end

    puts "\n" + "=" * 80
    puts "🏁 Local Test Matrix Results"
    puts "(CI automatically tests SQLite3 + PostgreSQL only)"
    puts "=" * 80

    if failed_combinations.empty?
      puts "✅ All combinations passed!"
    else
      puts "❌ Failed combinations:"
      failed_combinations.each { |combo| puts "  - #{combo}" }
      exit 1
    end
  end
end

# Override default test task
desc "Run all tests"
task test: "test:all"
