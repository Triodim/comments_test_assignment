# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  before_action :set_comment,        only: %i[show edit update destroy]
  before_action :require_ownership,  only: %i[edit update destroy]

  def index
    @search_query = params[:q].presence
    if @search_query
      @comments     = Comment.search(@search_query)
      @children_map = {}
      @next_cursor  = nil
    elsif params[:scroll_to].present?
      load_feed_for_scroll_to
    else
      batch         = Comment.feed_page(cursor: params[:cursor])
      @has_more     = batch.size > Comment::FEED_LIMIT
      @comments     = batch.first(Comment::FEED_LIMIT)
      @children_map = build_children_map(@comments)
      @next_cursor  = @has_more ? Comment.encode_cursor(@comments.last) : nil
    end
    @new_comment = Comment.new

    respond_to do |f|
      f.html
      f.turbo_stream
    end
  end

  def mine
    @comments = current_user.comments.includes(:user).order(created_at: :desc)
  end

  def show
    @children_map = build_children_map([@comment])
  end

  def create
    result = Comments::Create.call(
      user:      current_user,
      params:    comment_params,
      parent_id: params.dig(:comment, :parent_id),
    )
    @comment = result.comment
    @success = result.success?
    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to comments_path }
    end
  end

  def edit; end

  def update
    result = Comments::Update.call(comment: @comment, params: comment_params)
    @comment  = result.comment
    @success  = result.success?
    @children_map = @success ? build_children_map([@comment]) : {}
    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to comments_path }
    end
  end

  def destroy
    Comments::Destroy.call(comment: @comment)
    respond_to do |f|
      f.turbo_stream
      f.html { redirect_to comments_path }
    end
  end

  private

  def set_comment
    @comment = Comment.find(params[:id])
  end

  def require_ownership
    redirect_to comments_path, alert: 'Not authorized.' unless @comment.user == current_user
  end

  def comment_params
    params.require(:comment).permit(:body)
  end

  def load_feed_for_scroll_to
    scroll_to_param = params[:scroll_to]
    target = Comment.find_by(id: scroll_to_param)

    unless target
      first_page
      return
    end

    target_root    = target.root
    target_root_id = target_root.id
    first_batch    = Comment.feed_page(cursor: nil).to_a

    @comments = if first_batch.any? { |c| c.id == target_root_id }
      first_batch.first(Comment::FEED_LIMIT)
    else
      newer = Comment.roots
                     .includes(:user)
                     .where(
                       '(created_at > :ts) OR (created_at = :ts AND id > :id)',
                       ts: target_root.created_at, id: target_root_id,
                     )
                     .order(created_at: :desc, id: :desc)
                     .limit(Comment::FEED_LIMIT - 1)
                     .to_a
      target_root = Comment.includes(:user).find(target_root_id)
      sort_feed_desc(newer + [target_root])
    end

    @children_map = build_children_map(@comments)
    @next_cursor  = @comments.any? ? Comment.encode_cursor(@comments.last) : nil
    @scroll_to_id = scroll_to_param.to_s
  end

  def first_page
    batch         = Comment.feed_page(cursor: nil)
    @comments     = batch.first(Comment::FEED_LIMIT)
    @children_map = build_children_map(@comments)
    @next_cursor  = nil
  end

  def sort_feed_desc(comments)
    comments.sort_by { |comment| [-comment.created_at.to_f, -comment.id] }
  end

  def build_children_map(comments)
    return {} if comments.blank?
    Comment.descendants_for(comments.map(&:id)).group_by(&:parent_id)
  end
end
