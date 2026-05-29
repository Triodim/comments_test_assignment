# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Notification, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:actor).class_name('User') }
    it { is_expected.to belong_to(:comment) }
  end

  describe 'defaults' do
    it 'defaults read to false' do
      notification = create(:notification)
      expect(notification.read).to be false
    end
  end

  describe 'scopes' do
    let!(:unread) { create(:notification) }
    let!(:read)   { create(:notification, :read) }

    it '.unread returns only unread notifications' do
      expect(Notification.unread).to include(unread)
      expect(Notification.unread).not_to include(read)
    end
  end
end
