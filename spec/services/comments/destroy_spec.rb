# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Comments::Destroy do
  describe '#call' do
    it 'destroys the comment' do
      comment = create(:comment)
      expect { described_class.call(comment: comment) }
        .to change(Comment, :count).by(-1)
    end

    it 'returns success' do
      comment = create(:comment)
      result = described_class.call(comment: comment)
      expect(result).to be_success
    end

    it 'cascades to destroy child comments' do
      root  = create(:comment)
      child = create(:comment, parent: root)
      _grandchild = create(:comment, parent: child)

      expect { described_class.call(comment: root) }
        .to change(Comment, :count).by(-3)
    end
  end
end
