# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comments::Create do
  let(:user)   { create(:user) }
  let(:params) { ActionController::Parameters.new(body: 'Hello world').permit(:body) }

  describe '#call' do
    context 'with valid params' do
      it 'persists the comment' do
        expect { described_class.call(user: user, params: params) }
          .to change(Comment, :count).by(1)
      end

      it 'returns success' do
        result = described_class.call(user: user, params: params)
        expect(result).to be_success
      end

      it 'assigns the comment to the user' do
        result = described_class.call(user: user, params: params)
        expect(result.comment.user).to eq(user)
      end

      it 'creates a root comment when no parent_id given' do
        result = described_class.call(user: user, params: params)
        expect(result.comment).to be_root
      end

      it 'sets the parent when parent_id is provided' do
        parent = create(:comment)
        result = described_class.call(user: user, params: params, parent_id: parent.id)
        expect(result.comment.parent).to eq(parent)
      end

      it 'calls MentionNotifier on success' do
        expect(MentionNotifier).to receive(:call)
        described_class.call(user: user, params: params)
      end
    end

    context 'with invalid params' do
      let(:blank_params) { ActionController::Parameters.new(body: '').permit(:body) }

      it 'does not persist the comment' do
        expect { described_class.call(user: user, params: blank_params) }
          .not_to change(Comment, :count)
      end

      it 'returns failure' do
        result = described_class.call(user: user, params: blank_params)
        expect(result).not_to be_success
      end

      it 'populates errors' do
        result = described_class.call(user: user, params: blank_params)
        expect(result.errors).not_to be_empty
      end

      it 'does not call MentionNotifier' do
        expect(MentionNotifier).not_to receive(:call)
        described_class.call(user: user, params: blank_params)
      end
    end
  end
end
