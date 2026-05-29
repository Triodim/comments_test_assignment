# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  describe 'GET /comments' do
    it 'returns 200 for guests' do
      get comments_path
      expect(response).to have_http_status(:ok)
    end

    it 'returns 200 for authenticated users' do
      sign_in user
      get comments_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /comments/mine' do
    it 'redirects guests to login' do
      get mine_comments_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'returns 200 for authenticated user' do
      sign_in user
      get mine_comments_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST /comments' do
    context 'as guest' do
      it 'redirects to login' do
        post comments_path, params: { comment: { body: 'Hello' } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context 'as authenticated user' do
      before { sign_in user }

      it 'creates a root comment' do
        expect {
          post comments_path,
               params: { comment: { body: 'Hello' } },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change(Comment, :count).by(1)
      end

      it 'creates a reply when parent_id is given' do
        parent = create(:comment)
        expect {
          post comments_path,
               params: { comment: { body: 'Reply', parent_id: parent.id } },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change(Comment, :count).by(1)
        expect(Comment.last.parent).to eq(parent)
      end

      it 'rejects a depth-3 comment' do
        root   = create(:comment)
        depth1 = create(:comment, parent: root)
        depth2 = create(:comment, parent: depth1)
        expect {
          post comments_path,
               params: { comment: { body: 'Too deep', parent_id: depth2.id } },
               headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.not_to change(Comment, :count)
      end
    end
  end

  describe 'PATCH /comments/:id' do
    context 'as owner' do
      it 'updates the comment' do
        comment = create(:comment, user: user)
        sign_in user
        patch comment_path(comment),
              params: { comment: { body: 'Updated' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(comment.reload.body).to eq('Updated')
      end
    end

    context 'as non-owner' do
      it 'redirects away' do
        comment = create(:comment, user: other)
        sign_in user
        patch comment_path(comment),
              params: { comment: { body: 'Hijack' } },
              headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        expect(response).to redirect_to(comments_path)
      end
    end
  end

  describe 'DELETE /comments/:id' do
    context 'as owner' do
      it 'destroys the comment' do
        comment = create(:comment, user: user)
        sign_in user
        expect {
          delete comment_path(comment),
                 headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.to change(Comment, :count).by(-1)
      end
    end

    context 'as non-owner' do
      it 'redirects away and does not destroy' do
        comment = create(:comment, user: other)
        sign_in user
        expect {
          delete comment_path(comment),
                 headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
        }.not_to change(Comment, :count)
        expect(response).to redirect_to(comments_path)
      end
    end
  end
end
