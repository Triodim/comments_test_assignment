# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:notifications).dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }

    context 'depth limit' do
      let(:root)  { create(:comment) }
      let(:depth1) { create(:comment, parent: root) }
      let(:depth2) { create(:comment, parent: depth1) }

      it 'allows depth 0 (root)' do
        expect(root).to be_valid
      end

      it 'allows depth 1' do
        expect(depth1).to be_valid
      end

      it 'allows depth 2' do
        expect(depth2).to be_valid
      end

      it 'rejects depth 3' do
        depth3 = build(:comment, parent: depth2)
        expect(depth3).not_to be_valid
        expect(depth3.errors[:base]).to include('Maximum comment depth reached')
      end
    end
  end

  describe 'ancestry' do
    let(:root)   { create(:comment) }
    let(:child)  { create(:comment, parent: root) }
    let(:grandchild) { create(:comment, parent: child) }

    it 'identifies root comments' do
      expect(root).to be_root
    end

    it 'returns children' do
      child
      expect(root.children).to include(child)
    end

    it 'reports correct depth' do
      expect(root.depth).to eq(0)
      expect(child.depth).to eq(1)
      expect(grandchild.depth).to eq(2)
    end
  end

  describe 'scopes' do
    it '.roots returns only root comments' do
      root  = create(:comment)
      reply = create(:comment, parent: root)
      expect(Comment.roots).to include(root)
      expect(Comment.roots).not_to include(reply)
    end
  end
end
