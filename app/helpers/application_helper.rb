module ApplicationHelper
  include Pagy::Frontend

  def full_title
    if content_for?(:title)
      "#{content_for(:title)} | #{Rails.application.config.application_name}"
    else
      Rails.application.config.application_name
    end
  end

  def recipe_page_path(page, recipe_id: nil)
    params[:action] == "edit" ? edit_recipes_path(recipe_id: recipe_id, slug: page.slug) : setup_recipes_path(slug: page.slug)
  end
end
