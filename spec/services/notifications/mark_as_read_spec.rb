# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notifications::MarkAsRead do
  describe '#call' do
    it 'marks the notification as read' do
      notification = create(:notification)
      described_class.call(notification: notification)
      expect(notification.reload.read).to be true
    end

    it 'returns success' do
      notification = create(:notification)
      result = described_class.call(notification: notification)
      expect(result).to be_success
    end
  end
end
