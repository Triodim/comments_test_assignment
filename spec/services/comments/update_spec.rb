# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comments::Update do
  let(:comment) { create(:comment, body: 'Original body') }
  let(:params)  { ActionController::Parameters.new(body: 'Updated body').permit(:body) }

  describe '#call' do
    context 'with valid params' do
      it 'updates the comment body' do
        described_class.call(comment: comment, params: params)
        expect(comment.reload.body).to eq('Updated body')
      end

      it 'returns success' do
        result = described_class.call(comment: comment, params: params)
        expect(result).to be_success
      end

      it 'calls MentionNotifier with previous_body' do
        expect(MentionNotifier).to receive(:call).with(comment, previous_body: 'Original body')
        described_class.call(comment: comment, params: params)
      end
    end

    context 'with invalid params' do
      let(:blank_params) { ActionController::Parameters.new(body: '').permit(:body) }

      it 'does not update the body' do
        described_class.call(comment: comment, params: blank_params)
        expect(comment.reload.body).to eq('Original body')
      end

      it 'returns failure' do
        result = described_class.call(comment: comment, params: blank_params)
        expect(result).not_to be_success
      end

      it 'does not call MentionNotifier' do
        expect(MentionNotifier).not_to receive(:call)
        described_class.call(comment: comment, params: blank_params)
      end
    end
  end
end
