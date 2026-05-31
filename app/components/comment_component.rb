# frozen_string_literal: true

class CommentComponent < ApplicationComponent
  def initialize(comment:, current_user: nil, children_map: {})
    @comment      = comment
    @current_user = current_user
    @children_map = children_map
  end

  def owner?
    @current_user.present? && @current_user == @comment.user
  end

  def can_reply?
    @current_user.present? && @comment.depth < 2
  end

  def signed_in?
    @current_user.present?
  end

  def indent_class
    @comment.depth > 0 ? 'ml-6 mt-2' : ''
  end

  def children
    @children_map[@comment.id] || []
  end

  def reply_count
    @reply_count ||= children.size
  end

  def reply_count_label
    reply_count == 1 ? '1 reply' : "#{reply_count} replies"
  end

  def has_children?
    reply_count > 0
  end
end
