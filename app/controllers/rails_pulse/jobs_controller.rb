module RailsPulse
  class JobsController < ApplicationController
    include TagFilterConcern
    include Pagy::Backend

    before_action :set_job, only: :show

    def index
      @q = Job.ransack(params[:q])
      @pagy, @jobs = pagy(@q.result.order(runs_count: :desc), limit: session_pagination_limit)

      # Stats
      @total_jobs = Job.count
      @total_runs = JobRun.count
      @failed_runs = JobRun.where(status: %w[failed discarded]).count
      @avg_duration = Job.average(:avg_duration)&.to_f || 0
    end

    def show
      @q = @job.runs.ransack(params[:q])
      @pagy, @recent_runs = pagy(@q.result.order(occurred_at: :desc), limit: session_pagination_limit)

      # Performance metrics
      @avg_duration = @job.avg_duration&.to_f || 0
      @failure_rate = @job.failure_rate
    end

    private

    def set_job
      @job = Job.find(params[:id])
    end
  end
end
