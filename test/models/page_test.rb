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
    @basic_setup_page = pages(:basic_setup)
    @databases_group = @basic_setup_page.groups.find_by!(title: "Databases")
    @dev_env_group = @basic_setup_page.groups.find_by!(title: "Development Environment")

    @custom_ingredients_page = pages(:custom_ingredients)
    @your_custom_ingredients_group = @custom_ingredients_page.groups.find_by!(title: "Your Custom Ingredients")

    @relational_dbs = @databases_group.sub_groups.find_by!(title: "Relational Databases")
    @default_dbs = @databases_group.sub_groups.find_by!(title: "Default")
    @dev_env_default = @dev_env_group.sub_groups.find_by!(title: "Default")
    @your_custom_ingredients_default = @your_custom_ingredients_group.sub_groups.find_by!(title: "Default")

    @skip_git = @dev_env_default.elements.find_by!(label: "Skip Git")
    @sqlite3 = @default_dbs.elements.find_by!(label: "SQLite3")
    @app_name = @your_custom_ingredients_default.elements.find_by!(label: "App Name")
  end

  test "page has all associated groups" do
    basic_setup_expected_groups = [ "Databases", "Development Environment" ]
    assert_equal basic_setup_expected_groups.sort, @basic_setup_page.groups.pluck(:title).sort

    custom_ingredients_expected_groups = [ "Your Custom Ingredients" ]
    assert_equal custom_ingredients_expected_groups.sort, @custom_ingredients_page.groups.pluck(:title).sort
  end

  test "groups have all associated sub_groups" do
    assert_equal [ "Default", "Relational Databases", "Document Databases", "Key-Value Stores" ].sort, @databases_group.sub_groups.pluck(:title).sort
    assert_equal [ "Default" ], @dev_env_group.sub_groups.pluck(:title)
    assert_equal [ "Default" ], @your_custom_ingredients_group.sub_groups.pluck(:title)
  end

  test "sub_groups have all associated elements" do
    expected_default_dbs_elements = [ "SQLite3", "MySQL", "Trilogy", "PostgreSQL", "MariaDB (MySQL)", "MariaDB (Trilogy)" ]
    expected_dev_env_elements = [ "Skip Git", "Skip Docker", "Skip Action Mailer" ]
    expected_essentials_elements = [ "App Name" ]

    assert_equal expected_default_dbs_elements.sort, @default_dbs.elements.pluck(:label).sort
    assert_equal expected_dev_env_elements.sort, @dev_env_default.elements.pluck(:label).sort
    assert_equal expected_essentials_elements.sort, @your_custom_ingredients_default.elements.pluck(:label).sort
  end

  test "elements have correct variant types" do
    assert_equal "Element::Checkbox", @skip_git.variant_type
    assert_equal "Element::RadioButton", @sqlite3.variant_type
    assert_equal "Element::TextField", @app_name.variant_type
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
end
