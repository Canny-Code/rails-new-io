# == Schema Information
#
# Table name: pages
#
#  id         :integer          not null, primary key
#  position   :integer          default(0), not null
#  slug       :string           not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_pages_on_position  (position)
#  index_pages_on_slug      (slug) UNIQUE
#  index_pages_on_title     (title)
#
require "test_helper"

class PageTest < ActiveSupport::TestCase
  def setup
    @basic_setup_page = pages(:basic_setup)
    @databases_group = @basic_setup_page.groups.find_by!(title: "Databases")
    @dev_env_group = @basic_setup_page.groups.find_by!(title: "Development Environment")

    @relational_dbs = @databases_group.sub_groups.find_by!(title: "Relational Databases")
    @default_dbs = @databases_group.sub_groups.find_by!(title: "Default")
    @dev_env_default = @dev_env_group.sub_groups.find_by!(title: "Default")

    @skip_git = @dev_env_default.elements.find_by!(label: "Skip Git")
    @sqlite3 = @default_dbs.elements.find_by!(label: "SQLite3")
  end

  test "page has all associated groups" do
    basic_setup_expected_groups = [ "Databases", "Development Environment" ]
    assert_equal basic_setup_expected_groups.sort, @basic_setup_page.groups.pluck(:title).sort
  end

  test "groups have all associated sub_groups" do
    required_sub_groups = @databases_group.sub_groups.where(title: [ "Default", "Relational Databases" ])
    assert_equal [ "Default", "Relational Databases" ].sort, required_sub_groups.pluck(:title).sort
    assert_equal [ "Default" ], @dev_env_group.sub_groups.pluck(:title)
  end

  test "sub_groups have all associated elements" do
    expected_default_dbs_elements = [ "SQLite3", "PostgreSQL", "MySQL", "Trilogy", "MariaDB (MySQL)", "MariaDB (Trilogy)" ]
    expected_dev_env_elements = [ "Skip Git", "Skip Docker", "Skip Action Mailer" ]

    assert_equal expected_default_dbs_elements.sort, @default_dbs.elements.pluck(:label).sort
    assert_equal expected_dev_env_elements.sort, @dev_env_default.elements.pluck(:label).sort
  end

  test "elements have correct variant types" do
    assert_equal "Element::Checkbox", @skip_git.variant_type
    assert_equal "Element::RadioButton", @sqlite3.variant_type
  end

  test "title must be present" do
    @basic_setup_page.title = nil
    assert_not @basic_setup_page.valid?
    assert_includes @basic_setup_page.errors[:title], "can't be blank"
  end

  test "title must be unique" do
    duplicate_page = @basic_setup_page.dup
    assert_not duplicate_page.valid?
    assert_includes duplicate_page.errors[:title], "has already been taken"
  end

  test "slug cannot be blank" do
    @basic_setup_page.slug = ""
    assert_not @basic_setup_page.valid?
    assert_includes @basic_setup_page.errors[:slug], "can't be blank"
  end

  test "position must be present" do
    @basic_setup_page.position = nil
    assert_not @basic_setup_page.valid?
    assert_includes @basic_setup_page.errors[:position], "can't be blank"
  end

  test "position must be a non-negative integer" do
    @basic_setup_page.position = -1
    assert_not @basic_setup_page.valid?
    assert_includes @basic_setup_page.errors[:position], "must be greater than or equal to 0"

    @basic_setup_page.position = 1.5
    assert_not @basic_setup_page.valid?
    assert_includes @basic_setup_page.errors[:position], "must be an integer"
  end

  test "pages are ordered by position" do
    # Use higher positions to avoid conflicts with existing fixtures
    first_page = Page.create!(title: "First Page", position: 100, slug: "first-page")
    third_page = Page.create!(title: "Third Page", position: 102, slug: "third-page")
    second_page = Page.create!(title: "Second Page", position: 101, slug: "second-page")

    assert_equal [ first_page, second_page, third_page ], Page.where(position: 100..102).order(position: :asc).to_a
  end
end
