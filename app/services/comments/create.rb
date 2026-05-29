# frozen_string_literal: true

module Comments
  class Create < ApplicationService
    attr_reader :comment

    def initialize(user:, params:, parent_id: nil)
      @user      = user
      @params    = params
      @parent_id = parent_id
    end

    def call
      @comment = Comment.new(@params.merge(user: @user))

      if @parent_id.present?
        parent = Comment.find(@parent_id)
        @comment.parent = parent
      end

      if @comment.save
        MentionNotifier.call(@comment)
      else
        errors.concat(@comment.errors.full_messages)
      end

      self
    end
  end
end
