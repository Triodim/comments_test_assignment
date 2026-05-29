# frozen_string_literal: true

module Comments
  class Destroy < ApplicationService
    def initialize(comment:)
      @comment = comment
    end

    def call
      unless @comment.destroy
        errors.concat(@comment.errors.full_messages)
      end

      self
    end
  end
end
