# frozen_string_literal: true

class ReplyFormComponent < ApplicationComponent
  def initialize(parent_comment:)
    @parent_comment = parent_comment
  end
end
