# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :authenticate_user!, except: %i[index show]
  before_action :set_comment,        only: %i[show edit update destroy]
  before_action :require_ownership,  only: %i[edit update destroy]

  def index
    if params[:q].present?
      @comments     = Comment.search(params[:q])
      @children_map = {}
      @next_cursor  = nil
    else
      batch        = Comment.feed_page(cursor: params[:cursor])
      @has_more    = batch.size > Comment::FEED_LIMIT
      @comments    = batch.first(Comment::FEED_LIMIT)
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

  def build_children_map(comments)
    return {} if comments.blank?
    Comment.descendants_for(comments.map(&:id)).group_by(&:parent_id)
  end
end
