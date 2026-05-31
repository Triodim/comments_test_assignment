# frozen_string_literal: true

class Comment < ApplicationRecord
  include MeiliSearch::Rails

  FEED_LIMIT = 50

  has_ancestry

  belongs_to :user
  has_many   :notifications, dependent: :destroy

  validates :body, presence: true
  validate  :max_depth_not_exceeded

  # ── Feed pagination (cursor-based) ────────────────────────────────────────
  scope :feed_page, ->(cursor: nil, limit: FEED_LIMIT) {
    scope = roots.includes(:user).order(created_at: :desc, id: :desc).limit(limit + 1)
    if cursor
      ts, id = decode_cursor(cursor)
      scope = scope.where(
        '(created_at < :ts) OR (created_at = :ts AND id < :id)',
        ts: ts, id: id,
      ) if ts
    end
    scope
  }

  # ── Batch descendant loader (eliminates N+1) ──────────────────────────────
  # Loads all depth-1 and depth-2 children for a set of root IDs in one query.
  scope :descendants_for, ->(root_ids) {
    return none if root_ids.blank?
    ids = root_ids.map(&:to_s)
    base = where(ancestry: ids)
    ids.each { |id| base = base.or(where('ancestry LIKE ?', "#{id}/%")) }
    base.includes(:user).order(created_at: :asc, id: :asc)
  }

  # Legacy scope kept for non-paginated contexts (search result trees, etc.)
  scope :roots_with_tree, -> {
    roots.includes(:user).order(created_at: :desc)
  }

  # ── Cursor helpers ────────────────────────────────────────────────────────
  def self.encode_cursor(comment)
    Base64.urlsafe_encode64(
      "#{comment.created_at.utc.iso8601(6)}/#{comment.id}",
      padding: false,
    )
  end

  def self.decode_cursor(str)
    raw = Base64.urlsafe_decode64(str)
    ts_str, id_str = raw.split('/', 2)
    [Time.zone.parse(ts_str), id_str.to_i]
  rescue ArgumentError, TypeError
    nil
  end

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
