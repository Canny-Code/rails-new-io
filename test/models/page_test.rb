# == Schema Information
#
# Table name: pages
#
#  id         :integer          not null, primary key
#  slug       :string           not null
#  title      :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_pages_on_slug   (slug) UNIQUE
#  index_pages_on_title  (title)
#
require "test_helper"

class PageTest < ActiveSupport::TestCase
  def setup
    @page = pages(:basic_setup)
    @databases_group = @page.groups.find_by!(title: "Databases")
    @dev_env_group = @page.groups.find_by!(title: "Development Environment")
    @essentials_group = @page.groups.find_by!(title: "Essentials")

    @relational_dbs = @databases_group.sub_groups.find_by!(title: "Relational Databases")
    @dev_env_default = @dev_env_group.sub_groups.find_by!(title: "Default")
    @essentials_default = @essentials_group.sub_groups.find_by!(title: "Default")

    @skip_git = @dev_env_default.elements.find_by!(label: "Skip Git")
    @sqlite3 = @relational_dbs.elements.find_by!(label: "SQLite3")
    @app_name = @essentials_default.elements.find_by!(label: "App Name")
  end

  test "page has all associated groups" do
    expected_groups = [ "Databases", "Development Environment", "Essentials" ]
    assert_equal expected_groups.sort, @page.groups.pluck(:title).sort
  end

  test "groups have all associated sub_groups" do
    assert_equal [ "Relational Databases", "Document Databases", "Key-Value Stores" ].sort, @databases_group.sub_groups.pluck(:title).sort
    assert_equal [ "Default" ], @dev_env_group.sub_groups.pluck(:title)
    assert_equal [ "Default" ], @essentials_group.sub_groups.pluck(:title)
  end

  test "sub_groups have all associated elements" do
    expected_relational_dbs_elements = [ "SQLite3", "MySQL", "Trilogy", "PostgreSQL", "MariaDB (MySQL)", "MariaDB (Trilogy)" ]
    expected_dev_env_elements = [ "Skip Git", "Skip Docker", "Skip Action Mailer" ]
    expected_essentials_elements = [ "App Name" ]

    assert_equal expected_relational_dbs_elements.sort, @relational_dbs.elements.pluck(:label).sort
    assert_equal expected_dev_env_elements.sort, @dev_env_default.elements.pluck(:label).sort
    assert_equal expected_essentials_elements.sort, @essentials_default.elements.pluck(:label).sort
  end

  test "elements have correct variant types" do
    assert_equal "Element::Checkbox", @skip_git.variant_type
    assert_equal "Element::RadioButton", @sqlite3.variant_type
    assert_equal "Element::TextField", @app_name.variant_type
  end

  test "title must be present" do
    @page.title = nil
    assert_not @page.valid?
    assert_includes @page.errors[:title], "can't be blank"
  end

  test "title must be unique" do
    duplicate_page = @page.dup
    assert_not duplicate_page.valid?
    assert_includes duplicate_page.errors[:title], "has already been taken"
  end

  test "slug cannot be blank" do
    @page.slug = ""
    assert_not @page.valid?
    assert_includes @page.errors[:slug], "can't be blank"
  end
end
