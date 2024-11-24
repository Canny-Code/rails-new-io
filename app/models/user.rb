# == Schema Information
#
# Table name: users
#
#  id              :integer          not null, primary key
#  email           :string
#  github_token    :text
#  github_username :string           not null
#  image           :string
#  name            :string
#  provider        :string
#  slug            :string
#  uid             :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_users_on_github_username  (github_username) UNIQUE
#  index_users_on_slug             (slug) UNIQUE
#
class User < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  encrypts :github_token, deterministic: true, downcase: false

  has_many :repositories, dependent: :destroy
  has_many :generated_apps, dependent: :destroy

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
end
