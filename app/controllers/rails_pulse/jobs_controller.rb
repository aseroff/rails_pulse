module RailsPulse
  class JobsController < ApplicationController
    include TagFilterConcern
    include Pagy::Backend

    before_action :set_job, only: :show

    def index
      setup_metric_cards

      @ransack_query = Job.ransack(params[:q])
      @pagy, @jobs = pagy(@ransack_query.result.order(runs_count: :desc), limit: session_pagination_limit)
      @table_data = @jobs
      @available_queues = Job.distinct.pluck(:queue_name).compact.sort
    end

    def show
      @q = @job.runs.ransack(params[:q])
      @pagy, @recent_runs = pagy(@q.result.order(occurred_at: :desc), limit: session_pagination_limit)

      set_show_metrics
    end

    private

    def set_job
      @job = Job.find(params[:id])
    end

    def setup_metric_cards
      return if turbo_frame_request?

      @total_jobs_metric_card = RailsPulse::Jobs::Cards::TotalJobs.new.to_metric_card
      @total_runs_metric_card = RailsPulse::Jobs::Cards::TotalRuns.new.to_metric_card
      @failure_rate_metric_card = RailsPulse::Jobs::Cards::FailureRate.new.to_metric_card
      @average_duration_metric_card = RailsPulse::Jobs::Cards::AverageDuration.new.to_metric_card
    end

    def set_show_metrics
      @avg_duration = @job.avg_duration&.to_f || 0.0
      @failure_rate = @job.failure_rate
      @job_summaries = Summary
        .for_jobs
        .where(summarizable: @job, period_type: "day")
        .order(period_start: :desc)
        .limit(30)
    end
  end
end
