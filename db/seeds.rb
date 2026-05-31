# frozen_string_literal: true

# ─── Seed parameters ────────────────────────────────────────────────────────
USERS_COUNT         = 10  # random users to create (test user is always added)
COMMENTS_PER_USER   = 5   # root comments each user writes
REPLIES_PER_COMMENT = 3   # depth-1 replies per root comment
REPLIES_PER_REPLY   = 2   # depth-2 replies per depth-1 reply
MENTIONS_PER_USER   = 4   # @mention events spread across each user's comments
# ────────────────────────────────────────────────────────────────────────────

# ── Fandom helpers ────────────────────────────────────────────────────────────
CHARACTER_SOURCES = [
  -> { Faker::TvShows::GameOfThrones.character },
  -> { Faker::Movies::LordOfTheRings.character },
].freeze

QUOTE_SOURCES = [
  -> { Faker::TvShows::GameOfThrones.quote },
  -> { Faker::Movies::LordOfTheRings.quote },
].freeze

def fandom_username(suffix = nil)
  raw  = CHARACTER_SOURCES.sample.call
  base = raw.downcase
            .gsub("'", '')
            .gsub(/[^a-z0-9]+/, '_')
            .gsub(/\A_+|_+\z/, '')
            .slice(0, 25)
  suffix ? "#{base}_#{suffix}" : base
end

def unique_fandom_username
  counter = nil
  loop do
    candidate = fandom_username(counter)
    return candidate unless User.exists?(username: candidate)
    counter = (counter || 1) + 1
  end
end

def fandom_quote
  QUOTE_SOURCES.sample.call
rescue StandardError
  Faker::Lorem.paragraph(sentence_count: rand(1..3))
end
# ─────────────────────────────────────────────────────────────────────────────

puts "Seeding database…"
puts "  Users:               #{USERS_COUNT} random + 1 test account"
puts "  Comments per user:   #{COMMENTS_PER_USER}"
puts "  Replies per comment: #{REPLIES_PER_COMMENT}"
puts "  Depth-2 per reply:   #{REPLIES_PER_REPLY}"
puts "  Mentions per user:   #{MENTIONS_PER_USER}"
puts

if User.exists?
  puts "Database already seeded — skipping."
  return
end

# ── Test account (predefined credentials) ─────────────────────────────────────
puts "Creating test account…"

test_user = User.create!(
  username: 'tester',
  email:    'tester@example.com',
  password: 'password123',
)

puts "  Created: tester@example.com / password123"
puts

# ── Random users ──────────────────────────────────────────────────────────────
puts "Creating users…"

random_users = USERS_COUNT.times.map do
  User.create!(
    username: unique_fandom_username,
    email:    "#{unique_fandom_username}@example.com",
    password: 'password123',
  )
end

users = [test_user] + random_users

puts "  Created #{random_users.size} random users"
puts

# ── Root comments ─────────────────────────────────────────────────────────────
puts "Creating root comments…"

root_comments = []
users.each do |user|
  COMMENTS_PER_USER.times do
    root_comments << Comment.create!(body: fandom_quote, user: user)
  end
end

puts "  Created #{root_comments.size} root comments"
puts

# ── Depth-1 replies ───────────────────────────────────────────────────────────
puts "Creating depth-1 replies…"

depth1_comments = []
root_comments.each do |root|
  REPLIES_PER_COMMENT.times do
    author = users.reject { |u| u == root.user }.sample
    depth1_comments << Comment.create!(body: fandom_quote, user: author, parent: root)
  end
end

puts "  Created #{depth1_comments.size} depth-1 replies"
puts

# ── Depth-2 replies ───────────────────────────────────────────────────────────
puts "Creating depth-2 replies…"

depth2_comments = []
depth1_comments.each do |reply|
  REPLIES_PER_REPLY.times do
    author = users.reject { |u| u == reply.user }.sample
    depth2_comments << Comment.create!(body: fandom_quote, user: author, parent: reply)
  end
end

puts "  Created #{depth2_comments.size} depth-2 replies"
puts

# ── Mentions → Notifications ──────────────────────────────────────────────────
puts "Creating mentions and notifications…"

all_comments       = root_comments + depth1_comments + depth2_comments
notification_count = 0

def mention_user(comment, actor, target)
  mention_tag = "@#{target.username}"
  return if comment.body.include?(mention_tag)

  comment.update!(body: "#{comment.body} #{mention_tag}")

  unless Notification.exists?(user: target, comment: comment)
    Notification.create!(user: target, actor: actor, comment: comment, read: false)
    return true
  end
  false
end

# Random mentions across all users
users.each do |user|
  own_comments = all_comments.select { |c| c.user == user }
  next if own_comments.empty?

  MENTIONS_PER_USER.times do
    comment   = own_comments.sample
    mentioned = (users - [user]).sample
    next unless mentioned

    notification_count += 1 if mention_user(comment, user, mentioned)
  end
end

# Guarantee at least 3 notifications for the test user from random users
random_users.sample(3).each do |actor|
  comment = all_comments.select { |c| c.user == actor }.sample
  next unless comment

  notification_count += 1 if mention_user(comment, actor, test_user)
end

puts "  Created #{notification_count} notifications"
puts

# ── Summary ───────────────────────────────────────────────────────────────────
puts "Done! Database seeded with:"
puts "  #{User.count} users"
puts "  #{Comment.count} comments (#{root_comments.size} root · #{depth1_comments.size} depth-1 · #{depth2_comments.size} depth-2)"
puts "  #{Notification.count} notifications"
puts
puts "  Test account:  tester@example.com / password123"
