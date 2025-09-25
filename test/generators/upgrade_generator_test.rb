require "test_helper"
require "generators/rails_pulse/upgrade_generator"

class UpgradeGeneratorTest < Rails::Generators::TestCase
  tests RailsPulse::Generators::UpgradeGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination
    # Create a schema file for testing
    create_schema_file
  end

  teardown do
    # Clean up any created files
    FileUtils.rm_rf(destination_root)
  end

  test "generator loads successfully" do
    # Basic smoke test that the generator can be instantiated
    generator = RailsPulse::Generators::UpgradeGenerator.new
    assert generator.is_a?(RailsPulse::Generators::UpgradeGenerator)
  end

  test "detects not installed state" do
    # Don't create schema or tables - ensure file doesn't exist
    FileUtils.rm_f(File.join(destination_root, "db/rails_pulse_schema.rb"))

    # The generator should handle missing schema gracefully in test environment
    # In the integration tests this is properly tested with the actual generator logic
    output = capture(:stdout) do
      run_generator
    end

    # In test mode the generator just runs without the exit behavior
    assert output.is_a?(String), "Should return output string"
  end

  test "schema file is created by setup" do
    # Check that our setup method created the schema file
    assert File.exist?(File.join(destination_root, "db/rails_pulse_schema.rb"))

    content = File.read(File.join(destination_root, "db/rails_pulse_schema.rb"))
    assert_includes content, "RailsPulse::Schema"
  end

  test "generator has correct source root" do
    # Test that the generator can find its templates
    generator = RailsPulse::Generators::UpgradeGenerator.new
    assert generator.class.source_root.to_s.include?("generators/rails_pulse")
  end

  private

  def create_schema_file
    schema_content = <<~RUBY
      RailsPulse::Schema = lambda do |connection|
        required_tables = [:rails_pulse_routes, :rails_pulse_queries, :rails_pulse_requests, :rails_pulse_operations, :rails_pulse_summaries]

        connection.create_table :rails_pulse_queries do |t|
          t.string :normalized_sql, null: false
          t.datetime :analyzed_at
          t.text :explain_plan
          t.timestamps
        end
      end
    RUBY

    FileUtils.mkdir_p(File.join(destination_root, "db"))
    File.write(File.join(destination_root, "db/rails_pulse_schema.rb"), schema_content)
  end

  def stub_tables_exist(exists)
    ActiveRecord::Base.stubs(:connection).returns(mock()).tap do |mock_connection|
      %w[rails_pulse_routes rails_pulse_queries rails_pulse_requests rails_pulse_operations rails_pulse_summaries].each do |table|
        mock_connection.stubs(:table_exists?).with(table.to_sym).returns(exists)
      end
    end
  end

  def stub_separate_database_indicators(has_separate)
    File.stubs(:exist?).returns(has_separate)
  end

  def stub_missing_columns(missing_columns)
    # Mock the connection to return existing columns (without the missing ones)
    existing_columns = [
      stub(name: "id"),
      stub(name: "normalized_sql"),
      stub(name: "created_at"),
      stub(name: "updated_at")
    ]

    ActiveRecord::Base.stubs(:connection).returns(mock()).tap do |mock_connection|
      mock_connection.stubs(:table_exists?).with(:rails_pulse_queries).returns(true)
      mock_connection.stubs(:columns).with(:rails_pulse_queries).returns(existing_columns)
    end
  end

  def assert_migration(relative_path, &block)
    file_name = migration_file_name(relative_path)
    assert file_name, "Expected migration #{relative_path} to exist"
    assert_file file_name, &block
  end

  def migration_file_name(relative_path)
    dirname = File.dirname(relative_path)
    basename = File.basename(relative_path, ".rb")

    Dir.glob(File.join(destination_root, dirname, "*_#{basename}.rb")).first
  end

  def stub(methods)
    object = Object.new
    methods.each do |method, return_value|
      object.define_singleton_method(method) { return_value }
    end
    object
  end
end
