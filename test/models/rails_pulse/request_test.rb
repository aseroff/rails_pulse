require "test_helper"

class RailsPulse::RequestTest < ActiveSupport::TestCase
  include Shoulda::Matchers::ActiveModel
  include Shoulda::Matchers::ActiveRecord

  # Test associations
  test "should have correct associations" do
    assert belong_to(:route).matches?(RailsPulse::Request.new)
    assert have_many(:operations).dependent(:destroy).matches?(RailsPulse::Request.new)
  end

  # Test validations
  test "should have correct validations" do
    request = RailsPulse::Request.new

    # Presence validations
    assert validate_presence_of(:route_id).matches?(request)
    assert validate_presence_of(:occurred_at).matches?(request)
    assert validate_presence_of(:duration).matches?(request)
    assert validate_presence_of(:status).matches?(request)
    assert validate_presence_of(:request_uuid).matches?(request)

    # Numericality validation
    assert validate_numericality_of(:duration).is_greater_than_or_equal_to(0).matches?(request)

    # Uniqueness validation (test manually for cross-database compatibility)
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    existing_request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "existing-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    duplicate_request = RailsPulse::Request.new(route: route, duration: 150.5, status: 200, request_uuid: existing_request.request_uuid, controller_action: "UsersController#index", occurred_at: 1.hour.ago)

    refute_predicate duplicate_request, :valid?
    assert_includes duplicate_request.errors[:request_uuid], "has already been taken"
  end

  test "should be valid with required attributes" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)

    assert_predicate request, :valid?
  end

  # Uniqueness validation is covered by shoulda matcher above

  test "should generate request_uuid when blank" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.new(route: route, duration: 150.5, status: 200, controller_action: "UsersController#index", occurred_at: 1.hour.ago, request_uuid: nil)

    # Test the private method directly
    request.send(:set_request_uuid)

    assert_not_nil request.request_uuid
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, request.request_uuid)
  end

  # Association tests are covered by shoulda matchers above

  test "should return formatted string representation" do
    time = Time.parse("2024-01-15 14:30:00 UTC")
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: time)

    # The to_s method calls getlocal, so we need to expect the local time format
    expected_format = time.getlocal.strftime("%b %d, %Y %l:%M %p")

    assert_equal expected_format, request.to_s
  end

  test "should include ransackable attributes" do
    expected_attributes = %w[id route_id occurred_at duration status status_indicator route_path]

    assert_equal expected_attributes.sort, RailsPulse::Request.ransackable_attributes.sort
  end

  test "should include ransackable associations" do
    expected_associations = %w[route]

    assert_equal expected_associations.sort, RailsPulse::Request.ransackable_associations.sort
  end

  # Dependent destroy behavior is tested by shoulda matcher above

  test "operations association should return correct operations" do
    route1 = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    route2 = RailsPulse::Route.create!(method: "GET", path: "/api/posts")
    request1 = RailsPulse::Request.create!(route: route1, duration: 150.5, status: 200, request_uuid: "test-uuid-1", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    request2 = RailsPulse::Request.create!(route: route2, duration: 250.0, status: 200, request_uuid: "test-uuid-2", controller_action: "PostsController#index", occurred_at: 1.hour.ago)

    # Create operations for request1
    operation1 = RailsPulse::Operation.create!(request: request1, operation_type: "sql", label: "SELECT * FROM users", duration: 45.0, start_time: 10.0, occurred_at: 1.hour.ago)
    operation2 = RailsPulse::Operation.create!(request: request1, operation_type: "controller", label: "UsersController#index", duration: 25.0, start_time: 5.0, occurred_at: 1.hour.ago)

    # Create operation for request2
    operation3 = RailsPulse::Operation.create!(request: request2, operation_type: "sql", label: "SELECT * FROM posts", duration: 35.0, start_time: 8.0, occurred_at: 1.hour.ago)

    # Test that each request returns only its own operations
    assert_equal 2, request1.operations.count
    assert_includes request1.operations, operation1
    assert_includes request1.operations, operation2
    assert_not_includes request1.operations, operation3

    assert_equal 1, request2.operations.count
    assert_includes request2.operations, operation3
    assert_not_includes request2.operations, operation1
    assert_not_includes request2.operations, operation2
  end

  test "ransacker methods should be available" do
    # Test that ransacker class method exists
    assert_respond_to RailsPulse::Request, :ransacker
  end

  test "should handle edge case durations for status_indicator" do
    # Test requests at threshold boundaries
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    slow_request = RailsPulse::Request.create!(route: route, duration: 700.0, status: 200, request_uuid: "slow-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    very_slow_request = RailsPulse::Request.create!(route: route, duration: 2000.0, status: 200, request_uuid: "very-slow-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    critical_request = RailsPulse::Request.create!(route: route, duration: 4000.0, status: 200, request_uuid: "critical-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)

    # All should be valid
    assert_predicate slow_request, :valid?
    assert_predicate very_slow_request, :valid?
    assert_predicate critical_request, :valid?
  end

  test "request_uuid should be auto-generated if not provided" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.new(
      route: route,
      duration: 150.5,
      status: 200,
      controller_action: "UsersController#index",
      occurred_at: 1.hour.ago,
      request_uuid: nil
    )

    # Manually trigger the callback that should happen before validation
    request.send(:set_request_uuid)

    assert_not_nil request.request_uuid
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, request.request_uuid)
  end

  test "should not overwrite provided request_uuid" do
    custom_uuid = "12345678-1234-1234-1234-123456789012"
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: custom_uuid, controller_action: "UsersController#index", occurred_at: 1.hour.ago)

    assert_equal custom_uuid, request.request_uuid
  end

  test "should handle various HTTP status codes" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")

    status_codes = [ 200, 201, 400, 401, 404, 500, 503 ]

    status_codes.each do |status_code|
      request = RailsPulse::Request.create!(
        route: route,
        status: status_code,
        duration: 150.5,
        request_uuid: "uuid-#{status_code}",
        controller_action: "UsersController#index",
        occurred_at: 1.hour.ago,
        is_error: status_code >= 400
      )

      assert_predicate request, :valid?
      assert_equal status_code, request.status
      assert_equal (status_code >= 400), request.is_error
    end
  end
end
