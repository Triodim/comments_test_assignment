# frozen_string_literal: true

class Comment < ApplicationRecord
  include MeiliSearch::Rails

  has_ancestry

  belongs_to :user
  has_many   :notifications, dependent: :destroy

  validates :body, presence: true
  validate  :max_depth_not_exceeded

  scope :roots_with_tree, -> {
    roots.includes(:user).order(created_at: :desc)
  }

  meilisearch do
    attribute :body, :user_id, :created_at
    searchable_attributes [:body]
    filterable_attributes [:user_id]
    sortable_attributes   [:created_at]
    displayed_attributes  [:id, :body, :user_id, :created_at]
  end

  private

  def max_depth_not_exceeded
    errors.add(:base, 'Maximum comment depth reached') if depth >= 3
  end
end
