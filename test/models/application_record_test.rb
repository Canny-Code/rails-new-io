require "test_helper"

class ApplicationRecordTest < ActiveSupport::TestCase
  test "wtf returns error messages as a sentence" do
    recipe = recipes(:blog_recipe)
    recipe.name = nil
    recipe.valid?
    assert_equal "Name can't be blank", recipe.wtf
  end
end
