# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Notifications', type: :system do
  let!(:alice) { create(:user, username: 'alice') }
  let!(:bob)   { create(:user, username: 'bob') }

  before { driven_by(:rack_test) }

  it 'creates a notification when a user is mentioned' do
    sign_in alice
    visit comments_path
    fill_in 'comment[body]', with: 'Hello @bob'
    click_button 'Post Comment'
    expect(Notification.where(user: bob)).to exist
  end

  it 'shows bell badge for unread notifications' do
    create(:notification, user: bob)
    sign_in bob
    visit comments_path
    within('#notification_badge') do
      expect(page).to have_css('span', text: '1')
    end
  end

  it 'marks a notification as read and updates the badge' do
    notification = create(:notification, user: bob)
    sign_in bob
    visit notifications_path
    click_link 'Mark read'
    expect(notification.reload.read).to be true
  end

  it 'marks all notifications as read' do
    create_list(:notification, 3, user: bob)
    sign_in bob
    visit notifications_path
    click_link 'Mark all as read'
    expect(bob.notifications.unread).to be_empty
  end
end
