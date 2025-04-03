module ApplicationHelper
  include Pagy::Frontend

  def full_title
    if content_for?(:title)
      "#{content_for(:title)} | #{Rails.application.config.application_name}"
    else
      Rails.application.config.application_name
    end
  end

  def recipe_page_path(page, recipe_id: nil, onboarding_step: nil)
    path_params = { recipe_id: recipe_id, slug: page.slug }
    path_params[:onboarding_step] = onboarding_step if onboarding_step.present?
    params[:action] == "edit" ? edit_recipes_path(**path_params) : setup_recipes_path(**path_params)
  end
end
