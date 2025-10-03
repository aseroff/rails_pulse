require "bundler/setup"
require "bundler/gem_tasks"

# Load environment variables from .env file
require "dotenv/load" if File.exist?(".env")

APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

desc "Run test suite"
task :test do
  database = ENV['DB'] || 'sqlite3'

  # Get Rails version from Gemfile.lock or fallback
  rails_version = begin
    require 'rails'
    Rails.version
  rescue LoadError
    # Try to get from Gemfile.lock
    gemfile_lock = File.read('Gemfile.lock') rescue nil
    if gemfile_lock && gemfile_lock.match(/rails \(([^)]+)\)/)
      $1
    else
      'unknown'
    end
  end

  puts "\n" + "=" * 50
  puts "💛 Rails Pulse Test Suite"
  puts "=" * 50
  puts "Database: #{database.upcase}"
  puts "Rails: #{rails_version}"
  puts "=" * 50
  puts

  sh "rails test test/controllers test/helpers test/instrumentation test/models test/services"
end

desc "Test all database and Rails version combinations"
task :test_matrix do
  databases = %w[sqlite3 postgresql mysql2]
  rails_versions = %w[rails-7-2 rails-8-0]

  failed_combinations = []
  total_combinations = databases.size * rails_versions.size
  current = 0

  puts "\n" + "=" * 60
  puts "🚀 Rails Pulse Full Test Matrix"
  puts "=" * 60
  puts "Testing #{total_combinations} combinations..."
  puts "=" * 60

  databases.each do |database|
    rails_versions.each do |rails_version|
      current += 1

      puts "\n[#{current}/#{total_combinations}] Testing: #{database.upcase} + #{rails_version.upcase.gsub('-', ' ')}"
      puts "-" * 50

      begin
        if rails_version == "rails-8-0" && database == "sqlite3"
          # Current default setup
          sh "bundle exec rake test"
        else
          # Use appraisal with specific database
          sh "DB=#{database} bundle exec appraisal #{rails_version} rake test"
        end

        puts "✅ PASSED: #{database} + #{rails_version}"

      rescue => e
        puts "❌ FAILED: #{database} + #{rails_version}"
        puts "   Error: #{e.message}"
        failed_combinations << "#{database} + #{rails_version}"
      end
    end
  end

  puts "\n" + "=" * 60
  puts "🏁 Test Matrix Results"
  puts "=" * 60

  if failed_combinations.empty?
    puts "🎉 All #{total_combinations} combinations passed!"
  else
    puts "✅ Passed: #{total_combinations - failed_combinations.size}/#{total_combinations}"
    puts "❌ Failed combinations:"
    failed_combinations.each { |combo| puts "   • #{combo}" }
    exit 1
  end
end


task default: :test
