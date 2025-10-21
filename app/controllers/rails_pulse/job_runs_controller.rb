module RailsPulse
  class JobRunsController < ApplicationController
    include TagFilterConcern
    include Pagy::Backend

    before_action :set_job
    before_action :set_run, only: :show

    def index
      @q = @job.runs.ransack(params[:q])
      @pagy, @runs = pagy(@q.result.order(occurred_at: :desc), limit: session_pagination_limit)
    end

    def show
      @operations = @run.operations.order(:start_time)

      # Group operations by type
      @operations_by_type = @operations.group_by(&:operation_type)

      # SQL queries
      @sql_operations = @operations.where(operation_type: "sql")
                                   .includes(:query)
                                   .order(duration: :desc)
    end

    private

    def set_job
      @job = Job.find(params[:job_id])
    end

    def set_run
      @run = @job.runs.find(params[:id])
    end
  end
end
