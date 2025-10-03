require "test_helper"

class RailsPulse::SummaryTest < ActiveSupport::TestCase
  include Shoulda::Matchers::ActiveModel
  include Shoulda::Matchers::ActiveRecord

  # Test associations
  test "should have correct associations" do
    assert belong_to(:summarizable).optional.matches?(RailsPulse::Summary.new)
    assert belong_to(:route).optional.matches?(RailsPulse::Summary.new)
    assert belong_to(:query).optional.matches?(RailsPulse::Summary.new)
  end

  # Test validations
  test "should have correct validations" do
    summary = RailsPulse::Summary.new

    # Inclusion validation
    assert validate_inclusion_of(:period_type).in_array(RailsPulse::Summary::PERIOD_TYPES).matches?(summary)

    # Presence validations
    assert validate_presence_of(:period_start).matches?(summary)
    assert validate_presence_of(:period_end).matches?(summary)
  end

  test "should be valid with required attributes" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    summary = RailsPulse::Summary.create!(
      summarizable: route,
      period_start: 1.hour.ago.beginning_of_hour,
      period_end: 1.hour.ago.end_of_hour,
      period_type: "hour",
      count: 150,
      avg_duration: 180.5
    )

    assert_predicate summary, :valid?
  end

  test "should have correct period types constant" do
    expected_types = %w[hour day week month]

    assert_equal expected_types, RailsPulse::Summary::PERIOD_TYPES
  end

  test "should include ransackable attributes" do
    expected_attributes = %w[
      period_start period_end avg_duration min_duration max_duration count error_count
      requests_per_minute error_rate_percentage route_path_cont
      execution_count total_time_consumed normalized_sql
      summarizable_id summarizable_type
    ]

    assert_equal expected_attributes.sort, RailsPulse::Summary.ransackable_attributes.sort
  end

  test "should include ransackable associations" do
    expected_associations = %w[route query]

    assert_equal expected_associations.sort, RailsPulse::Summary.ransackable_associations.sort
  end

  test "should have scopes" do
    # Test for_period_type scope
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    hour_summary = RailsPulse::Summary.create!(summarizable: route, period_start: 1.hour.ago.beginning_of_hour, period_end: 1.hour.ago.end_of_hour, period_type: "hour", count: 150, avg_duration: 180.5)
    day_summary = RailsPulse::Summary.create!(summarizable: route, period_start: 1.day.ago.beginning_of_day, period_end: 1.day.ago.end_of_day, period_type: "day", count: 300, avg_duration: 150.0)

    hour_summaries = RailsPulse::Summary.for_period_type("hour")

    assert_includes hour_summaries, hour_summary
    assert_not_includes hour_summaries, day_summary

    # Test for_date_range scope
    start_date = 1.day.ago.beginning_of_day
    end_date = Time.current.end_of_day

    recent_summary = RailsPulse::Summary.create!(summarizable: route, period_start: Time.current.beginning_of_hour, period_end: Time.current.end_of_hour, period_type: "hour", count: 50, avg_duration: 100.0)
    old_summary = RailsPulse::Summary.create!(summarizable: route, period_start: 2.days.ago.beginning_of_hour, period_end: 2.days.ago.end_of_hour, period_type: "hour", count: 25, avg_duration: 200.0)

    range_summaries = RailsPulse::Summary.for_date_range(start_date, end_date)

    assert_includes range_summaries, recent_summary
    assert_not_includes range_summaries, old_summary

    # Test for_requests scope
    route2 = RailsPulse::Route.create!(method: "POST", path: "/api/posts")
    request = RailsPulse::Request.create!(route: route2, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "PostsController#create", occurred_at: 1.hour.ago)
    request_summary = RailsPulse::Summary.create!(summarizable: request, period_start: 1.hour.ago.beginning_of_hour, period_end: 1.hour.ago.end_of_hour, period_type: "hour", count: 100, avg_duration: 120.0)
    route_summary = RailsPulse::Summary.create!(summarizable: route2, period_start: 2.hours.ago.beginning_of_hour, period_end: 2.hours.ago.end_of_hour, period_type: "hour", count: 200, avg_duration: 80.0)

    request_summaries = RailsPulse::Summary.for_requests

    assert_includes request_summaries, request_summary
    assert_not_includes request_summaries, route_summary

    # Test for_routes scope
    route_summaries = RailsPulse::Summary.for_routes

    assert_includes route_summaries, route_summary
    assert_not_includes route_summaries, request_summary

    # Test for_queries scope
    query = RailsPulse::Query.create!(normalized_sql: "SELECT * FROM posts WHERE id = ?")
    query_summary = RailsPulse::Summary.create!(summarizable: query, period_start: 3.hours.ago.beginning_of_hour, period_end: 3.hours.ago.end_of_hour, period_type: "hour", count: 75, avg_duration: 45.0)
    query_summaries = RailsPulse::Summary.for_queries

    assert_includes query_summaries, query_summary
    assert_not_includes query_summaries, route_summary

    # Test overall_requests scope
    overall_summary = RailsPulse::Summary.create!(summarizable_type: "RailsPulse::Request", summarizable_id: 0, period_start: 2.hours.ago.beginning_of_hour, period_end: 2.hours.ago.end_of_hour, period_type: "hour", count: 500, avg_duration: 150.0)
    specific_summary = RailsPulse::Summary.create!(summarizable_type: "RailsPulse::Request", summarizable_id: 1, period_start: 4.hours.ago.beginning_of_hour, period_end: 4.hours.ago.end_of_hour, period_type: "hour", count: 50, avg_duration: 100.0)

    overall_summaries = RailsPulse::Summary.overall_requests

    assert_includes overall_summaries, overall_summary
    assert_not_includes overall_summaries, specific_summary
  end

  test "should work with polymorphic associations" do
    route3 = RailsPulse::Route.create!(method: "GET", path: "/api/test")
    query2 = RailsPulse::Query.create!(normalized_sql: "SELECT * FROM test WHERE id = ?")

    route_summary = RailsPulse::Summary.create!(summarizable: route3, period_start: 1.hour.ago.beginning_of_hour, period_end: 1.hour.ago.end_of_hour, period_type: "hour", count: 75, avg_duration: 90.0)
    query_summary = RailsPulse::Summary.create!(summarizable: query2, period_start: 1.hour.ago.beginning_of_hour, period_end: 1.hour.ago.end_of_hour, period_type: "hour", count: 40, avg_duration: 30.0)

    assert_equal route3, route_summary.summarizable
    assert_equal query2, query_summary.summarizable
    assert_equal "RailsPulse::Route", route_summary.summarizable_type
    assert_equal "RailsPulse::Query", query_summary.summarizable_type
  end

  test "should calculate period end correctly" do
    time = Time.parse("2024-01-15 14:30:00 UTC")

    assert_equal time.end_of_hour, RailsPulse::Summary.calculate_period_end("hour", time)
    assert_equal time.end_of_day, RailsPulse::Summary.calculate_period_end("day", time)
    assert_equal time.end_of_week, RailsPulse::Summary.calculate_period_end("week", time)
    assert_equal time.end_of_month, RailsPulse::Summary.calculate_period_end("month", time)
  end

  test "should normalize period start correctly" do
    time = Time.parse("2024-01-15 14:30:00 UTC")

    assert_equal time.beginning_of_hour, RailsPulse::Summary.normalize_period_start("hour", time)
    assert_equal time.beginning_of_day, RailsPulse::Summary.normalize_period_start("day", time)
    assert_equal time.beginning_of_week, RailsPulse::Summary.normalize_period_start("week", time)
    assert_equal time.beginning_of_month, RailsPulse::Summary.normalize_period_start("month", time)
  end

  test "should order by recent scope" do
    route4 = RailsPulse::Route.create!(method: "DELETE", path: "/api/cleanup")
    old_summary = RailsPulse::Summary.create!(summarizable: route4, period_start: 2.hours.ago, period_end: 2.hours.ago + 1.hour, period_type: "hour", count: 10, avg_duration: 50.0)
    new_summary = RailsPulse::Summary.create!(summarizable: route4, period_start: 1.hour.ago, period_end: 1.hour.ago + 1.hour, period_type: "hour", count: 20, avg_duration: 75.0)

    recent_summaries = RailsPulse::Summary.recent

    assert_equal [ new_summary, old_summary ], recent_summaries.to_a
  end
end
