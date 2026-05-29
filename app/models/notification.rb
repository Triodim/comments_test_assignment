# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor, class_name: 'User', foreign_key: :actor_id, inverse_of: :sent_notifications
  belongs_to :comment

  scope :unread,   -> { where(read: false) }
  scope :recent,   -> { order(created_at: :desc) }
  scope :for_user, ->(user) { where(user: user) }
end
