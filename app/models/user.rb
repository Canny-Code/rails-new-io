# == Schema Information
#
# Table name: users
#
#  id                   :integer          not null, primary key
#  admin                :boolean          default(FALSE), not null
#  email                :string
#  github_token         :text
#  github_username      :string           not null
#  image                :string
#  name                 :string
#  onboarding_completed :boolean          default(FALSE)
#  provider             :string
#  slug                 :string
#  uid                  :string
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#
# Indexes
#
#  index_users_on_github_username  (github_username) UNIQUE
#  index_users_on_slug             (slug) UNIQUE
#
class User < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  encrypts :github_token

  has_many :generated_apps, dependent: :nullify
  has_many :recipes, foreign_key: :created_by_id, dependent: :destroy
  has_many :notifications, as: :recipient,
                          dependent: :destroy,
                          class_name: "Noticed::Notification"
  has_many :ingredients, foreign_key: :created_by_id, dependent: :destroy
  has_many :elements, dependent: :destroy

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :github_username, presence: true, uniqueness: true

  def self.from_omniauth(omniauth_params)
    provider = omniauth_params.provider
    uid = omniauth_params.uid

    user = User.find_or_initialize_by(provider:, uid:)
    user.email = omniauth_params.info.email
    user.name = omniauth_params.info.name
    user.image = omniauth_params.info.image
    user.github_username = omniauth_params.dig("extra", "raw_info", "login")
    user.github_token = omniauth_params.dig("credentials", "token")
    user.save if user.valid?

    user
  end

  def notifications
    Noticed::Notification.where(recipient: self)
  end

  def should_start_onboarding?
    generated_apps.empty? && recipes.empty? && ingredients.empty? && !onboarding_completed?
  end
end
