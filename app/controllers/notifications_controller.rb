# frozen_string_literal: true

class NotificationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_notification, only: [:mark_as_read]

  def index
    @notifications = current_user.notifications.recent.includes(:actor, :comment)
  end

  def mark_as_read
    Notifications::MarkAsRead.call(notification: @notification)
    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to notifications_path }
    end
  end

  def mark_all_as_read
    Notifications::MarkAllAsRead.call(user: current_user)
    @notifications = current_user.notifications.recent.includes(:actor, :comment)
    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to notifications_path }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
