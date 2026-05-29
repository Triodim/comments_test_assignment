# frozen_string_literal: true

module Comments
  class Update < ApplicationService
    attr_reader :comment

    def initialize(comment:, params:)
      @comment = comment
      @params  = params
    end

    def call
      previous_body = @comment.body

      if @comment.update(@params)
        MentionNotifier.call(@comment, previous_body: previous_body)
      else
        errors.concat(@comment.errors.full_messages)
      end

      self
    end
  end
end
