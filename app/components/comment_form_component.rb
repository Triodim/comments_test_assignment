# frozen_string_literal: true

class CommentFormComponent < ApplicationComponent
  def initialize(comment:, url:, parent_id: nil, submit_label: 'Post Comment')
    @comment = comment
    @url = url
    @parent_id = parent_id
    @submit_label = submit_label
  end
end
