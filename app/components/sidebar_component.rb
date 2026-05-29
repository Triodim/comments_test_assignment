# frozen_string_literal: true

class SidebarComponent < ApplicationComponent
  def initialize(current_user: nil)
    @current_user = current_user
  end

  def signed_in?
    @current_user.present?
  end

  def comment_count
    @comment_count ||= @current_user.comments.count
  end

  def nav_link_class(path)
    active = helpers.current_page?(path)
    base = 'px-3 py-2 rounded-md text-sm font-medium'
    active ? "#{base} bg-indigo-50 text-indigo-700" : "#{base} text-gray-600 hover:bg-gray-50"
  end
end
