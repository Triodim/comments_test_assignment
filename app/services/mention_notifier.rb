# frozen_string_literal: true

class MentionNotifier
  def self.call(comment, previous_body: nil)
    new(comment, previous_body: previous_body).call
  end

  def initialize(comment, previous_body: nil)
    @comment       = comment
    @previous_body = previous_body
  end

  def call
    @previous_body ? sync_notifications : create_notifications(mentioned_users(@comment.body))
  end

  private

  def sync_notifications
    current_users  = mentioned_users(@comment.body)
    previous_users = mentioned_users(@previous_body)

    removed = previous_users - current_users
    added   = current_users - previous_users

    delete_notifications(removed)
    create_notifications(added)
  end

  def mentioned_users(body)
    usernames = body.scan(/\B@(\w+)/).flatten.map(&:downcase).uniq
    usernames -= [@comment.user.username.downcase]

    return [] if usernames.empty?

    User.where('lower(username) IN (?)', usernames).to_a
  end

  def create_notifications(users)
    users.each do |user|
      Notification.create!(
        user:    user,
        actor:   @comment.user,
        comment: @comment,
        read:    false,
      )
    end
  end

  def delete_notifications(users)
    return if users.empty?

    Notification.where(comment: @comment, user: users).destroy_all
  end
end
