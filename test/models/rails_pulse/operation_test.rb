require "test_helper"

class RailsPulse::OperationTest < ActiveSupport::TestCase
  include Shoulda::Matchers::ActiveModel
  include Shoulda::Matchers::ActiveRecord

  # Test associations
  test "should have correct associations" do
    assert belong_to(:request).matches?(RailsPulse::Operation.new)
    assert belong_to(:query).optional.matches?(RailsPulse::Operation.new)
  end

  # Test validations
  test "should have correct validations" do
    operation = RailsPulse::Operation.new

    # Presence validations
    assert validate_presence_of(:request_id).matches?(operation)
    assert validate_presence_of(:operation_type).matches?(operation)
    assert validate_presence_of(:label).matches?(operation)
    assert validate_presence_of(:occurred_at).matches?(operation)
    assert validate_presence_of(:duration).matches?(operation)

    # Inclusion validation
    assert validate_inclusion_of(:operation_type).in_array(RailsPulse::Operation::OPERATION_TYPES).matches?(operation)

    # Numericality validation
    assert validate_numericality_of(:duration).is_greater_than_or_equal_to(0).matches?(operation)
  end

  test "should be valid with required attributes" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    operation = RailsPulse::Operation.create!(
      request: request,
      operation_type: "sql",
      label: "SELECT * FROM users WHERE id = ?",
      duration: 45.0,
      start_time: 10.0,
      codebase_location: "app/models/user.rb:25",
      occurred_at: 1.hour.ago
    )

    assert_predicate operation, :valid?
  end

  test "should have correct operation types constant" do
    expected_types = %w[sql controller template partial layout collection cache_read cache_write http job mailer storage]

    assert_equal expected_types, RailsPulse::Operation::OPERATION_TYPES
  end

  test "should include ransackable attributes" do
    expected_attributes = %w[id occurred_at label duration start_time average_query_time_ms query_count operation_type query_id]

    assert_equal expected_attributes.sort, RailsPulse::Operation.ransackable_attributes.sort
  end

  test "should include ransackable associations" do
    expected_associations = []

    assert_equal expected_associations.sort, RailsPulse::Operation.ransackable_associations.sort
  end

  test "should have by_type scope" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)

    sql_operation = RailsPulse::Operation.create!(request: request, operation_type: "sql", label: "SELECT * FROM users", duration: 45.0, start_time: 10.0, occurred_at: 1.hour.ago)
    controller_operation = RailsPulse::Operation.create!(request: request, operation_type: "controller", label: "UsersController#index", duration: 25.0, start_time: 5.0, occurred_at: 1.hour.ago)

    sql_operations = RailsPulse::Operation.by_type("sql")

    assert_includes sql_operations, sql_operation
    assert_not_includes sql_operations, controller_operation
  end

  test "should associate query for sql operations" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    operation = RailsPulse::Operation.create!(
      request: request,
      operation_type: "sql",
      label: "SELECT * FROM users WHERE id = ?",
      duration: 45.0,
      start_time: 10.0,
      occurred_at: 1.hour.ago
    )

    assert_not_nil operation.query
    assert_instance_of RailsPulse::Query, operation.query
    assert_equal "SELECT * FROM users WHERE id = ?", operation.query.normalized_sql
  end

  test "should not associate query for non-sql operations" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    operation = RailsPulse::Operation.create!(
      request: request,
      operation_type: "template",
      label: "render users/index.html.erb",
      duration: 25.0,
      start_time: 75.0,
      occurred_at: 1.hour.ago
    )

    assert_nil operation.query
  end

  test "should return id as string representation" do
    route = RailsPulse::Route.create!(method: "GET", path: "/api/users")
    request = RailsPulse::Request.create!(route: route, duration: 150.5, status: 200, request_uuid: "test-uuid", controller_action: "UsersController#index", occurred_at: 1.hour.ago)
    operation = RailsPulse::Operation.create!(
      request: request,
      operation_type: "sql",
      label: "SELECT * FROM users WHERE id = ?",
      duration: 45.0,
      start_time: 10.0,
      occurred_at: 1.hour.ago
    )

    assert_equal operation.id, operation.to_s
  end
end
