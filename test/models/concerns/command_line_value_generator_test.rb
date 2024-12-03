require "test_helper"

class CommandLineValueGeneratorTest < ActiveSupport::TestCase
  class DummyClass
    include CommandLineValueGenerator
    attr_accessor :label, :sub_group

    def initialize(label: nil, sub_group: nil)
      @label = label
      @sub_group = sub_group
    end
  end

  setup do
    @group = Minitest::Mock.new
    @sub_group = Minitest::Mock.new
  end

  test "generates command line value for database choice" do
    @group.expect :behavior_type, "database_choice"
    @sub_group.expect :group, @group

    instance = DummyClass.new(label: "PostgreSQL", sub_group: @sub_group)
    assert_equal "postgresql", instance.generate_command_line_value
  end

  test "generates command line value for generic checkbox" do
    @group.expect :behavior_type, "generic_checkbox"
    @sub_group.expect :group, @group

    instance = DummyClass.new(
      label: "Add Something",
      sub_group: @sub_group
    )
    assert_equal "--skip-something", instance.generate_command_line_value
  end

  test "generates command line value for other behavior type" do
    @group.expect :behavior_type, "other"
    @sub_group.expect :group, @group

    instance = DummyClass.new(
      label: "Add something?",
      sub_group: @sub_group
    )
    assert_equal "--skip-something", instance.generate_command_line_value
  end

  test "handles override cases in generic checkbox" do
    instance = DummyClass.new(label: "Run bundle install?")
    assert_equal "--skip-bundle", instance.generate_generic_checkbox_command_line_value
  end

  test "generates generic checkbox values" do
    test_cases = {
      "Add Something" => "--skip-something",
      "Include API Mode" => "--skip-api",
      "Add Active Storage" => "--skip-active-storage",
      "Add Git" => "--skip-git",
      "Use ActiveRecord" => "--skip-active-record"
    }

    test_cases.each do |input_label, expected|
      instance = DummyClass.new(label: input_label)
      assert_equal expected, instance.generate_generic_checkbox_command_line_value
    end

    # Test override case separately
    instance = DummyClass.new(label: "Include `.keep` files?")
    assert_equal "--skip-keep", instance.generate_generic_checkbox_command_line_value
  end

  test "generates database choice values" do
    test_cases = {
      "PostgreSQL" => "postgresql",
      "MySQL" => "mysql",
      "SQLite" => "sqlite3",
      "Trilogy" => "trilogy",
      "MariaDB (10.3)" => "mariadb-10.3",
      "PostgreSQL (15.0)" => "postgresql-15.0",
      "Other DB" => "otherdb",
      "MariaDB (MySQL)" => "mariadb-mysql"
    }

    test_cases.each do |input_label, expected|
      instance = DummyClass.new(label: input_label)
      assert_equal expected, instance.generate_database_choice_command_line_value
    end
  end
end
