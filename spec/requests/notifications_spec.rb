# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications', type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  before { sign_in user }

  describe 'GET /notifications' do
    it 'returns own notifications only' do
      own   = create(:notification, user: user)
      theirs = create(:notification, user: other)
      get notifications_path
      expect(response.body).to include("notification-#{own.id}")
      expect(response.body).not_to include("notification-#{theirs.id}")
    end
  end

  describe 'PATCH /notifications/:id/mark_as_read' do
    it 'marks own notification as read' do
      notification = create(:notification, user: user)
      patch mark_as_read_notification_path(notification),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(notification.reload.read).to be true
    end

    it 'returns 404 for another user\'s notification' do
      notification = create(:notification, user: other)
      patch mark_as_read_notification_path(notification),
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /notifications/mark_all_as_read' do
    it 'marks all own unread notifications as read' do
      create_list(:notification, 3, user: user)
      patch mark_all_as_read_notifications_path,
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(user.notifications.unread).to be_empty
    end

    it 'does not affect other users\' notifications' do
      other_notification = create(:notification, user: other)
      patch mark_all_as_read_notifications_path,
            headers: { 'Accept' => 'text/vnd.turbo-stream.html' }
      expect(other_notification.reload.read).to be false
    end
  end
end
