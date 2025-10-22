module RailsPulse
  module Jobs
    module Cards
      class TotalJobs < Base
        def initialize(job: nil)
          @job = job
        end

        def to_metric_card
          # When scoped to a job, show runs count instead of job count
          if @job
            total_runs = @job.runs_count

            {
              id: "jobs_total_jobs",
              context: "jobs",
              title: "Total Runs",
              summary: "#{format_number(total_runs)} runs",
              chart_data: {},
              trend_icon: "move-right",
              trend_amount: "0%",
              trend_text: ""
            }
          else
            total_jobs = RailsPulse::Job.count

            current_new_jobs = RailsPulse::Job.where(created_at: current_window_start..now).count
            previous_new_jobs = RailsPulse::Job.where(created_at: range_start...current_window_start).count

            trend_icon, trend_amount = trend_for(current_new_jobs, previous_new_jobs)

            grouped_new_jobs = RailsPulse::Job
              .where(created_at: range_start..now)
              .group_by_day(:created_at, time_zone: "UTC")
              .count

            {
              id: "jobs_total_jobs",
              context: "jobs",
              title: "Total Jobs",
              summary: "#{format_number(total_jobs)} jobs",
              chart_data: sparkline_from(grouped_new_jobs),
              trend_icon: trend_icon,
              trend_amount: trend_amount,
              trend_text: "New jobs vs previous week"
            }
          end
        end
      end
    end
  end
end
