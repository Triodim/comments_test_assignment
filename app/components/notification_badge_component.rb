# frozen_string_literal: true

class NotificationBadgeComponent < ApplicationComponent
  def initialize(current_user:)
    @current_user = current_user
  end

  def unread_count
    @unread_count ||= @current_user.notifications.unread.count
  end

  def show_badge?
    unread_count > 0
  end

  def badge_label
    unread_count > 9 ? '9+' : unread_count.to_s
  end
end
