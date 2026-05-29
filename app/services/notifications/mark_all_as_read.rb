# frozen_string_literal: true

module Notifications
  class MarkAllAsRead < ApplicationService
    def initialize(user:)
      @user = user
    end

    def call
      @user.notifications.unread.update_all(read: true)
      self
    end
  end
end
