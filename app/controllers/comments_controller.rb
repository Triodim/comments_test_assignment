# frozen_string_literal: true

class CommentsController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  before_action :set_comment,        only: %i[edit update destroy]
  before_action :require_ownership,  only: %i[edit update destroy]

  def index
    @comments = if params[:q].present?
      Comment.search(params[:q])
    else
      Comment.roots_with_tree
    end
    @new_comment = Comment.new
  end

  def mine
    @comments = current_user.comments.includes(:user).order(created_at: :desc)
  end

  def create
    result = Comments::Create.call(
      user:      current_user,
      params:    comment_params,
      parent_id: params.dig(:comment, :parent_id),
    )
    @comment = result.comment
    @success = result.success?
    respond_to { |f| f.turbo_stream }
  end

  def edit; end

  def update
    result = Comments::Update.call(comment: @comment, params: comment_params)
    @comment = result.comment
    @success = result.success?
    respond_to { |f| f.turbo_stream }
  end

  def destroy
    Comments::Destroy.call(comment: @comment)
    respond_to { |f| f.turbo_stream }
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
end
