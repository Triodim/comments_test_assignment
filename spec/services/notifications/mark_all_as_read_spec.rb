# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::MarkAllAsRead do
  describe '#call' do
    let(:user)  { create(:user) }
    let(:other) { create(:user) }

    it 'marks all unread notifications for the user as read' do
      create_list(:notification, 3, user: user)
      described_class.call(user: user)
      expect(user.notifications.unread).to be_empty
    end

    it 'does not affect other users\' notifications' do
      other_notification = create(:notification, user: other)
      described_class.call(user: user)
      expect(other_notification.reload.read).to be false
    end

    it 'returns success' do
      result = described_class.call(user: user)
      expect(result).to be_success
    end
  end
end
