# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :system do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  before { driven_by(:rack_test) }

  describe 'guest view' do
    it 'shows root comments without forms or subcomments' do
      root  = create(:comment)
      reply = create(:comment, parent: root)
      visit comments_path
      expect(page).to have_css("#comment-#{root.id}")
      expect(page).not_to have_css("#comment-#{reply.id}")
      expect(page).not_to have_css('#new-comment-form')
    end

    it 'shows sign-in prompt instead of comment form' do
      visit comments_path
      expect(page).to have_link('Sign in')
      expect(page).to have_link('sign up')
    end
  end

  describe 'authenticated user' do
    before { sign_in user }

    it 'sees the new comment form' do
      visit comments_path
      expect(page).to have_css('#new-comment-form')
    end

    it 'creates a root comment and sees it appear' do
      visit comments_path
      fill_in 'comment[body]', with: 'My new comment'
      click_button 'Post Comment'
      expect(page).to have_content('My new comment')
    end

    it 'posts a reply nested under the parent' do
      root = create(:comment)
      visit comments_path
      # Target the reply form directly by its DOM id — bypasses the Stimulus
      # toggle which requires JS (not available with rack_test driver)
      within("#reply-form-comment-#{root.id}") do
        fill_in 'comment[body]', with: 'My reply'
        click_button 'Post Reply'
      end
      expect(page).to have_content('My reply')
    end

    it 'shows edit and delete buttons only on own comments' do
      own_comment   = create(:comment, user: user)
      other_comment = create(:comment, user: other)
      visit comments_path
      within("div#comment-#{own_comment.id}") do
        expect(page).to have_link('Edit')
        expect(page).to have_link('Delete')
      end
      within("div#comment-#{other_comment.id}") do
        expect(page).not_to have_link('Edit')
        expect(page).not_to have_link('Delete')
      end
    end

    it 'edits own comment in-place' do
      comment = create(:comment, user: user, body: 'Before edit')
      visit comments_path
      within("div#comment-#{comment.id}") { click_link 'Edit' }
      fill_in 'comment[body]', with: 'After edit'
      click_button 'Save Changes'
      expect(page).to have_content('After edit')
      expect(page).not_to have_content('Before edit')
    end

    it 'hides the reply button at depth 2' do
      root   = create(:comment)
      depth1 = create(:comment, parent: root)
      depth2 = create(:comment, parent: depth1)
      visit comments_path
      within("div#comment-#{depth2.id}") do
        expect(page).not_to have_button('Reply')
      end
    end
  end
end
