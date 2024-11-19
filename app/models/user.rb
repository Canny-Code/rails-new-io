# == Schema Information
#
# Table name: users
#
#  id         :integer          not null, primary key
#  email      :string
#  image      :string
#  name       :string
#  provider   :string
#  slug       :string
#  uid        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_users_on_slug  (slug) UNIQUE
#
class User < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  def self.create_from_omniauth(omniauth_params)
    provider = omniauth_params.provider
    uid = omniauth_params.uid

    user = User.find_or_initialize_by(provider:, uid:)
    user.email = omniauth_params.info.email
    user.name = omniauth_params.info.name
    user.image = omniauth_params.info.image
    user.save
    user
  end
end
