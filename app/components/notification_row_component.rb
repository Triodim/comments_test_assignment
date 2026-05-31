# frozen_string_literal: true

class NotificationRowComponent < ApplicationComponent
  def initialize(notification:)
    @notification = notification
  end

  def row_class
    border = @notification.read? ? 'border-gray-200' : 'border-indigo-200 bg-indigo-50'
    "bg-white rounded-lg border #{border} p-4 flex items-center justify-between gap-4"
  end

  def link_class
    @notification.read? ? 'text-sm text-gray-600 hover:underline' : 'text-sm text-indigo-800 font-medium hover:underline'
  end
end
