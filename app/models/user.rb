# frozen_string_literal: true

class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :comments,           dependent: :destroy
  has_many :notifications,      dependent: :destroy
  has_many :sent_notifications, class_name: 'Notification',
                                foreign_key: :actor_id,
                                dependent: :destroy,
                                inverse_of: :actor

  validates :username,
            presence: true,
            uniqueness: { case_sensitive: false },
            format: { with: /\A\w+\z/, message: 'only letters, numbers, and underscores' },
            length: { minimum: 2, maximum: 30 }
end
