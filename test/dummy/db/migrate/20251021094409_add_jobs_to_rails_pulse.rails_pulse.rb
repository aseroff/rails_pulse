# This migration comes from rails_pulse (originally 20251001000000)
class AddJobsToRailsPulse < ActiveRecord::Migration["#{Rails::VERSION::MAJOR}.#{Rails::VERSION::MINOR}".to_f]
  def up
    create_table :rails_pulse_jobs do |t|
      t.string :name, null: false
      t.string :queue_name
      t.text :description
      t.integer :runs_count, null: false, default: 0
      t.integer :failures_count, null: false, default: 0
      t.integer :retries_count, null: false, default: 0
      t.decimal :avg_duration, precision: 15, scale: 6
      t.text :tags
      t.timestamps
    end

    add_index :rails_pulse_jobs, :name, unique: true
    add_index :rails_pulse_jobs, :queue_name
    add_index :rails_pulse_jobs, :runs_count

    create_table :rails_pulse_job_runs do |t|
      t.references :job, null: false, foreign_key: { to_table: :rails_pulse_jobs }
      t.string :run_id, null: false
      t.decimal :duration, precision: 15, scale: 6
      t.string :status, null: false
      t.string :error_class
      t.text :error_message
      t.integer :attempts, null: false, default: 0
      t.timestamp :occurred_at, null: false
      t.timestamp :enqueued_at
      t.text :arguments
      t.string :adapter
      t.text :tags
      t.timestamps
    end

    add_index :rails_pulse_job_runs, :run_id, unique: true
    add_index :rails_pulse_job_runs, [ :job_id, :occurred_at ]
    add_index :rails_pulse_job_runs, :occurred_at
    add_index :rails_pulse_job_runs, :status
    add_index :rails_pulse_job_runs, [ :job_id, :status ]

    change_column_null :rails_pulse_operations, :request_id, true
    add_reference :rails_pulse_operations, :job_run, foreign_key: { to_table: :rails_pulse_job_runs }

    orphan_count = select_value(<<~SQL.squish).to_i
      SELECT COUNT(*)
      FROM rails_pulse_operations
      WHERE request_id IS NULL AND job_run_id IS NULL
    SQL

    if orphan_count.positive?
      raise ActiveRecord::IrreversibleMigration, "Cannot add constraint: #{orphan_count} operations missing request and job run"
    end

    adapter = connection.adapter_name.downcase

    if adapter.include?("postgres") || adapter.include?("mysql")
      options = {}
      options[:validate] = false if adapter.include?("postgres")

      add_check_constraint :rails_pulse_operations,
        "(request_id IS NOT NULL OR job_run_id IS NOT NULL)",
        name: "rails_pulse_operations_request_or_job_run",
        **options

      validate_check_constraint :rails_pulse_operations, name: "rails_pulse_operations_request_or_job_run" if adapter.include?("postgres")
    end
  end

  def down
    adapter = connection.adapter_name.downcase
    remove_check_constraint :rails_pulse_operations, name: "rails_pulse_operations_request_or_job_run" if adapter.include?("postgres") || adapter.include?("mysql")
    remove_reference :rails_pulse_operations, :job_run, foreign_key: true
    change_column_null :rails_pulse_operations, :request_id, false
    drop_table :rails_pulse_job_runs
    drop_table :rails_pulse_jobs
  end
end
