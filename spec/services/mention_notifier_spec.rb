# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MentionNotifier do
  let!(:author) { create(:user, username: 'author') }
  let!(:bob)    { create(:user, username: 'bob') }
  let!(:alice)  { create(:user, username: 'alice') }

  describe '.call on create' do
    it 'creates a notification for a mentioned user' do
      comment = create(:comment, user: author, body: "Hello @bob")
      expect { described_class.call(comment) }
        .to change(Notification, :count).by(1)
    end

    it 'creates notifications for multiple different mentions' do
      comment = create(:comment, user: author, body: "Hello @bob and @alice")
      expect { described_class.call(comment) }
        .to change(Notification, :count).by(2)
    end

    it 'deduplicates repeated mentions of the same user' do
      comment = create(:comment, user: author, body: "@bob @bob @bob")
      expect { described_class.call(comment) }
        .to change(Notification, :count).by(1)
    end

    it 'does not notify the comment author (self-mention)' do
      self_mention_author = create(:user, username: 'selfie')
      comment = create(:comment, user: self_mention_author, body: "I am @selfie")
      expect { described_class.call(comment) }
        .not_to change(Notification, :count)
    end

    it 'ignores non-existent usernames' do
      comment = create(:comment, user: author, body: "Hello @nobody_here")
      expect { described_class.call(comment) }
        .not_to change(Notification, :count)
    end

    it 'notifies the correct user' do
      comment = create(:comment, user: author, body: "Hey @bob")
      described_class.call(comment)
      notification = Notification.last
      expect(notification.user).to eq(bob)
      expect(notification.actor).to eq(author)
      expect(notification.comment).to eq(comment)
    end
  end

  describe '.call on update' do
    it 'creates notification for a newly added mention' do
      comment = create(:comment, user: author, body: "No mentions")
      described_class.call(comment)

      comment.update!(body: "Now mentioning @bob")
      expect { described_class.call(comment, previous_body: "No mentions") }
        .to change(Notification, :count).by(1)
    end

    it 'deletes notification for a removed mention' do
      comment = create(:comment, user: author, body: "Hello @bob")
      described_class.call(comment)
      expect(Notification.count).to eq(1)

      comment.update!(body: "Mention removed")
      described_class.call(comment, previous_body: "Hello @bob")
      expect(Notification.count).to eq(0)
    end

    it 'is a no-op when mentions are unchanged' do
      comment = create(:comment, user: author, body: "Hey @bob")
      described_class.call(comment)

      expect { described_class.call(comment, previous_body: "Hey @bob") }
        .not_to change(Notification, :count)
    end
  end
end
