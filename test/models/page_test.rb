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
  include GitTestHelper

  setup do
    @page = Page.new(
      title: "Test Page",
      slug: "test-page",
      position: 1
    )

    setup_github_mocks
  end

  test "validates presence of title" do
    @page.title = nil
    assert_not @page.valid?
    assert_includes @page.errors[:title], "can't be blank"
  end

  test "validates presence of slug" do
    @page.slug = nil
    assert_not @page.valid?
    assert_includes @page.errors[:slug], "can't be blank"
  end

  test "validates presence of position" do
    @page.position = nil
    assert_not @page.valid?
    assert_includes @page.errors[:position], "can't be blank"
  end

  test "creates initial commit when created" do
    expect_github_operations(create_repo: true)
    assert @page.save
  end

  test "syncs to git when updated" do
    expect_github_operations(create_repo: true)
    assert @page.save

    expect_github_operations
    @page.update(title: "Updated Title")
  end
end
