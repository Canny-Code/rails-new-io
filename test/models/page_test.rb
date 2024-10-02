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
  end

  test "page has all associated groups" do
    expected_groups = [ "Databases", "Development Environment" ]
    assert_equal expected_groups.sort, @page.groups.pluck(:title).sort
  end

  test "groups have all associated sub_groups" do
    databases_group = @page.groups.find_by(title: "Databases")
    dev_env_group = @page.groups.find_by(title: "Development Environment")

    assert_equal [ "Relational Databases", "Document Databases", "Key-Value Stores" ].sort, databases_group.sub_groups.pluck(:title).sort
    assert_equal [ "Default" ], dev_env_group.sub_groups.pluck(:title)
  end

  test "sub_groups have all associated elements" do
    relational_dbs = SubGroup.find_by(title: "Relational Databases")
    dev_env_default = SubGroup.find_by(title: "Default")

    expected_relational_dbs_elements = [ "SQLite3", "MySQL", "Trilogy", "PostgreSQL", "MariaDB (MySQL)", "MariaDB (Trilogy)" ]
    expected_dev_env_elements = [ "Skip Git", "Skip Docker", "Skip Action Mailer" ]

    assert_equal expected_relational_dbs_elements.sort, relational_dbs.elements.pluck(:label).sort
    assert_equal expected_dev_env_elements.sort, dev_env_default.elements.pluck(:label).sort
  end

  test "elements have correct variant types" do
    skip_git = Element.find_by(label: "Skip Git")
    sqlite3 = Element.find_by(label: "SQLite3")

    assert_equal "Element::Checkbox", skip_git.variant_type
    assert_equal "Element::RadioButton", sqlite3.variant_type
  end
end
