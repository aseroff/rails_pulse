require "test_helper"
require "generators/rails_pulse/convert_to_migrations_generator"

class ConvertToMigrationsGeneratorTest < Rails::Generators::TestCase
  tests RailsPulse::Generators::ConvertToMigrationsGenerator
  destination Rails.root.join("tmp/generators")

  setup do
    prepare_destination
  end

  teardown do
    FileUtils.rm_rf(destination_root)
  end

  test "exits with error when no schema file exists" do
    # Use capture to catch the output since it exits
    assert_raises(SystemExit) do
      capture(:stdout) { run_generator }
    end
  end

  test "creates conversion migration when schema exists" do
    create_schema_file

    # Mock the table existence check to return false (no tables exist)
    RailsPulse::Generators::ConvertToMigrationsGenerator.any_instance.stubs(:rails_pulse_tables_exist?).returns(false)

    run_generator

    assert_migration "db/migrate/install_rails_pulse_tables.rb" do |content|
      assert_match(/class InstallRailsPulseTables/, content)
      assert_match(/load schema_file/, content)
      assert_match(/RailsPulse::Schema\.call\(connection\)/, content)
    end
  end

  test "exits when tables already exist" do
    create_schema_file

    # Mock the table existence check to return true (tables exist)
    RailsPulse::Generators::ConvertToMigrationsGenerator.any_instance.stubs(:rails_pulse_tables_exist?).returns(true)

    assert_raises(SystemExit) do
      capture(:stdout) { run_generator }
    end
  end

  test "migration template uses correct Rails migration version" do
    create_schema_file
    RailsPulse::Generators::ConvertToMigrationsGenerator.any_instance.stubs(:rails_pulse_tables_exist?).returns(false)

    run_generator

    assert_migration "db/migrate/install_rails_pulse_tables.rb" do |content|
      expected_version = ActiveRecord::Migration.current_version
      assert_match(/ActiveRecord::Migration\[#{expected_version}\]/, content)
    end
  end

  private

  def create_schema_file
    schema_content = <<~RUBY
      # Rails Pulse Database Schema
      RailsPulse::Schema = lambda do |connection|
        required_tables = [:rails_pulse_routes, :rails_pulse_queries, :rails_pulse_requests, :rails_pulse_operations, :rails_pulse_summaries]

        return if required_tables.all? { |table| connection.table_exists?(table) }

        connection.create_table :rails_pulse_routes do |t|
          t.string :method, null: false
          t.string :path, null: false
          t.timestamps
        end

        connection.create_table :rails_pulse_queries do |t|
          t.string :normalized_sql, null: false
          t.datetime :analyzed_at
          t.text :explain_plan
          t.timestamps
        end

        connection.create_table :rails_pulse_requests do |t|
          t.references :route, null: false
          t.decimal :duration, precision: 15, scale: 6, null: false
          t.timestamps
        end

        connection.create_table :rails_pulse_operations do |t|
          t.references :request, null: false
          t.string :operation_type, null: false
          t.timestamps
        end

        connection.create_table :rails_pulse_summaries do |t|
          t.datetime :period_start, null: false
          t.string :period_type, null: false
          t.timestamps
        end
      end

      if defined?(RailsPulse::ApplicationRecord)
        RailsPulse::Schema.call(RailsPulse::ApplicationRecord.connection)
      end
    RUBY

    FileUtils.mkdir_p(File.join(destination_root, "db"))
    File.write(File.join(destination_root, "db/rails_pulse_schema.rb"), schema_content)
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
end
