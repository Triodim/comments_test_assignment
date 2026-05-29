# frozen_string_literal: true

# ─── Seed parameters ────────────────────────────────────────────────────────
USERS_COUNT         = 10   # total users to create
COMMENTS_PER_USER   = 5    # root comments each user writes
REPLIES_PER_COMMENT = 3    # depth-1 replies per root comment
REPLIES_PER_REPLY   = 2    # depth-2 replies per depth-1 reply
MENTIONS_PER_USER   = 4    # @mention events spread across each user's comments
# ────────────────────────────────────────────────────────────────────────────

puts "Seeding database..."
puts "  Users: #{USERS_COUNT}"
puts "  Root comments per user: #{COMMENTS_PER_USER}"
puts "  Replies per comment: #{REPLIES_PER_COMMENT}"
puts "  Depth-2 replies per reply: #{REPLIES_PER_REPLY}"
puts "  Mention events per user: #{MENTIONS_PER_USER}"
puts

# ── Users ────────────────────────────────────────────────────────────────────
puts "Creating users..."

users = USERS_COUNT.times.map do |i|
  username = "#{Faker::Internet.unique.username(specifier: 4..15, separators: ['_'])}"
             .gsub(/[^a-z0-9_]/i, '_')
             .first(30)

  User.find_or_create_by!(username: username) do |u|
    u.email    = Faker::Internet.unique.email
    u.password = 'password123'
  end
end

puts "  Created #{users.size} users: #{users.map(&:username).join(', ')}"
puts

# ── Root comments ────────────────────────────────────────────────────────────
puts "Creating root comments..."

root_comments = []

users.each do |user|
  COMMENTS_PER_USER.times do
    comment = Comment.create!(
      body: Faker::Lorem.paragraph(sentence_count: rand(1..4)),
      user: user,
    )
    root_comments << comment
  end
end

puts "  Created #{root_comments.size} root comments"
puts

# ── Depth-1 replies ───────────────────────────────────────────────────────────
puts "Creating depth-1 replies..."

depth1_comments = []

root_comments.each do |root|
  REPLIES_PER_COMMENT.times do
    author = users.reject { |u| u == root.user }.sample
    comment = Comment.create!(
      body: Faker::Lorem.paragraph(sentence_count: rand(1..3)),
      user: author,
      parent: root,
    )
    depth1_comments << comment
  end
end

puts "  Created #{depth1_comments.size} depth-1 replies"
puts

# ── Depth-2 replies ───────────────────────────────────────────────────────────
puts "Creating depth-2 replies..."

depth2_comments = []

depth1_comments.each do |reply|
  REPLIES_PER_REPLY.times do
    author = users.reject { |u| u == reply.user }.sample
    comment = Comment.create!(
      body: Faker::Lorem.paragraph(sentence_count: rand(1..2)),
      user: author,
      parent: reply,
    )
    depth2_comments << comment
  end
end

puts "  Created #{depth2_comments.size} depth-2 replies"
puts

# ── Mentions → Notifications ──────────────────────────────────────────────────
puts "Creating mentions and notifications..."

all_comments = root_comments + depth1_comments + depth2_comments
notification_count = 0

users.each do |user|
  own_comments = all_comments.select { |c| c.user == user }
  next if own_comments.empty?

  MENTIONS_PER_USER.times do
    comment    = own_comments.sample
    mentioned  = (users - [user]).sample
    next unless mentioned

    mention_tag = "@#{mentioned.username}"
    next if comment.body.include?(mention_tag)

    new_body = "#{comment.body} #{mention_tag}"
    comment.update!(body: new_body)

    unless Notification.exists?(user: mentioned, comment: comment)
      Notification.create!(
        user:    mentioned,
        actor:   user,
        comment: comment,
        read:    [true, false].sample,
      )
      notification_count += 1
    end
  end
end

puts "  Created #{notification_count} notifications"
puts

# ── Summary ───────────────────────────────────────────────────────────────────
total_comments = root_comments.size + depth1_comments.size + depth2_comments.size

puts "Done! Database seeded with:"
puts "  #{User.count} users"
puts "  #{Comment.count} comments (#{root_comments.size} root · #{depth1_comments.size} depth-1 · #{depth2_comments.size} depth-2)"
puts "  #{Notification.count} notifications"
