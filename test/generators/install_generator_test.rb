require "test_helper"
require "generators/rails_pulse/install_generator"

class InstallGeneratorTest < Rails::Generators::TestCase
  tests RailsPulse::Generators::InstallGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination
  end

  teardown do
    # Clean up any created files
    FileUtils.rm_rf(destination_root)
  end

  test "generates schema file for single database setup" do
    run_generator [ "--database=single" ]

    assert_file "db/rails_pulse_schema.rb" do |content|
      assert_match(/RailsPulse::Schema = lambda/, content)
      assert_match(/rails_pulse_routes/, content)
      assert_match(/rails_pulse_queries/, content)
      assert_match(/rails_pulse_requests/, content)
      assert_match(/rails_pulse_operations/, content)
      assert_match(/rails_pulse_summaries/, content)
    end
  end

  test "generates initializer file" do
    run_generator

    assert_file "config/initializers/rails_pulse.rb" do |content|
      assert_match(/RailsPulse\.configure/, content)
      assert_match(/config\.enabled/, content)
    end
  end

  test "creates migration directory for future migrations" do
    run_generator

    assert_file "db/rails_pulse_migrate/.keep"
  end

  test "generates installation migration for single database" do
    run_generator [ "--database=single" ]

    assert_migration "db/migrate/install_rails_pulse_tables.rb" do |content|
      assert_match(/class InstallRailsPulseTables/, content)
      assert_match(/load schema_file/, content)
      assert_match(/RailsPulse::Schema\.call\(connection\)/, content)
      assert_match(/single source of truth/, content)
    end
  end

  test "does not generate migration for separate database setup" do
    run_generator [ "--database=separate" ]

    assert_no_migration "db/migrate/install_rails_pulse_tables.rb"
  end

  test "displays correct instructions for single database setup" do
    output = run_generator [ "--database=single" ]

    assert_match(/Rails Pulse installation complete! \(Single Database Setup\)/, output)
    assert_match(/rails db:migrate/, output)
    assert_match(/single source of truth/, output)
    assert_no_match(/Delete.*rails_pulse_schema\.rb/, output)
  end

  test "displays correct instructions for separate database setup" do
    output = run_generator [ "--database=separate" ]

    assert_match(/Rails Pulse installation complete! \(Separate Database Setup\)/, output)
    assert_match(/rails db:prepare/, output)
    assert_match(/single source of truth/, output)
    assert_match(/db\/rails_pulse_migrate/, output)
  end

  test "schema file contains all required tables" do
    run_generator

    assert_file "db/rails_pulse_schema.rb" do |content|
      # Check that all required tables are defined
      required_tables = [
        :rails_pulse_routes,
        :rails_pulse_queries,
        :rails_pulse_requests,
        :rails_pulse_operations,
        :rails_pulse_summaries
      ]

      required_tables.each do |table|
        assert_match(/connection\.create_table :#{table}/, content)
      end

      # Check for recent query analysis columns
      assert_match(/analyzed_at/, content)
      assert_match(/explain_plan/, content)
      assert_match(/index_recommendations/, content)
      assert_match(/n_plus_one_analysis/, content)

      # Check for summaries table polymorphic association
      assert_match(/summarizable.*polymorphic/, content)
    end
  end

  test "migration loads schema correctly in test environment" do
    run_generator [ "--database=single" ]

    # Simulate the migration execution
    schema_file = File.join(destination_root, "db/rails_pulse_schema.rb")

    assert_path_exists schema_file, "Schema file should exist"

    # Load the schema file and verify it defines the lambda
    load schema_file

    assert defined?(RailsPulse::Schema), "RailsPulse::Schema should be defined"
    assert_kind_of Proc, RailsPulse::Schema, "RailsPulse::Schema should be a lambda"
  end

  private

  def assert_migration(relative_path, &block)
    file_name = migration_file_name(relative_path)

    assert file_name, "Expected migration #{relative_path} to exist"
    assert_file file_name, &block
  end

  def assert_no_migration(relative_path)
    file_name = migration_file_name(relative_path)

    assert_not file_name, "Expected migration #{relative_path} not to exist"
  end

  def migration_file_name(relative_path)
    dirname = File.dirname(relative_path)
    basename = File.basename(relative_path, ".rb")

    Dir.glob(File.join(destination_root, dirname, "*_#{basename}.rb")).first
  end
end
