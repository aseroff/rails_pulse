ENV["RAILS_ENV"] = "test"

# Load environment variables from .env file for database configuration
require "dotenv/load" if File.exist?(".env")

require_relative "../test/dummy/config/environment"
require "rails/test_help"
require "factory_bot_rails"
require "shoulda-matchers"
require "mocha/minitest"

# Load rails-controller-testing for controller tests
begin
  require "rails-controller-testing"
rescue LoadError
  puts "Warning: rails-controller-testing not available for testing"
end


class ActiveSupport::TestCase
  # Enable parallel testing for local performance
  parallelize(workers: :number_of_processors)

  # Use Rails' built-in transactional cleanup
  self.use_transactional_tests = true

  include FactoryBot::Syntax::Methods

  # Configure FactoryBot
  FactoryBot.definition_file_paths = [File.expand_path("factories", __dir__)]
  FactoryBot.find_definitions

  # Configure Shoulda Matchers
  Shoulda::Matchers.configure do |config|
    config.integrate do |with|
      with.test_framework :minitest
      with.library :rails
    end
  end

  include Shoulda::Matchers::ActiveModel
  include Shoulda::Matchers::ActiveRecord
end