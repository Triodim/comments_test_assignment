# frozen_string_literal: true

module Notifications
  class MarkAsRead < ApplicationService
    def initialize(notification:)
      @notification = notification
    end

    def call
      @notification.update!(read: true)
      self
    rescue ActiveRecord::RecordInvalid => e
      errors << e.message
      self
    end
  end
end
