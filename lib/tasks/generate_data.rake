# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# Internal generator class — keeps the rake task body thin.
# ─────────────────────────────────────────────────────────────────────────────
class SeedDataGenerator
  def initialize(users_count:, comments_per_user:, mentions_per_user:, subcomments_per_user:)
    @users_count          = users_count
    @comments_per_user    = comments_per_user
    @mentions_per_user    = mentions_per_user
    @subcomments_per_user = subcomments_per_user
  end

  def run
    @users         = create_users
    @root_comments = create_root_comments
    @subcomments   = create_subcomments
    create_mentions
    reindex_meilisearch
    print_summary
  end

  private

  # ── Step 1: users ──────────────────────────────────────────────────────────
  def create_users
    log "Creating #{@users_count} users…"
    users = @users_count.times.map do
      username = "user_#{SecureRandom.hex(4)}"
      User.create!(
        username: username,
        email:    "#{username}@example.com",
        password: 'password123',
      )
    end
    log "  ✓ #{users.size} users (password: password123)"
    users
  end

  # ── Step 2: root comments ─────────────────────────────────────────────────
  def create_root_comments
    total = @users_count * @comments_per_user
    log "Creating #{total} root comments (#{@comments_per_user} per user)…"
    comments = []
    Comment.without_auto_index do
      @users.each do |user|
        @comments_per_user.times do
          comments << Comment.create!(
            body: Faker::Lorem.paragraph(sentence_count: rand(1..4)),
            user: user,
          )
        end
      end
    end
    log "  ✓ #{comments.size} root comments"
    comments
  end

  # ── Step 3: subcomments (depth-1 replies on other users' roots) ───────────
  def create_subcomments
    log "Creating subcomments (#{@subcomments_per_user} per user on other users' roots)…"
    subcomments = []
    Comment.without_auto_index do
      @users.each do |user|
        candidates = @root_comments.reject { |c| c.user_id == user.id }
        next if candidates.empty?

        targets = candidates.sample([@subcomments_per_user, candidates.size].min)
        targets.each do |root|
          subcomments << Comment.create!(
            body:   Faker::Lorem.paragraph(sentence_count: rand(1..3)),
            user:   user,
            parent: root,
          )
        end
      end
    end
    log "  ✓ #{subcomments.size} subcomments"
    subcomments
  end

  # ── Step 4: @mention events → notifications ───────────────────────────────
  def create_mentions
    log "Creating mentions (#{@mentions_per_user} per user)…"
    all_comments       = @root_comments + @subcomments
    notification_count = 0

    @users.each do |user|
      own_comments = all_comments.select { |c| c.user_id == user.id }
      next if own_comments.empty?

      other_users = @users.reject { |u| u.id == user.id }
      next if other_users.empty?

      @mentions_per_user.times do
        comment = own_comments.sample
        target  = other_users.sample
        mention = "@#{target.username}"

        # Skip if this comment already mentions this user
        next if comment.body.include?(mention)

        # Append mention to body (update_columns bypasses callbacks intentionally —
        # we reindex everything in bulk at the end)
        new_body = "#{comment.body} #{mention}"
        comment.update_columns(body: new_body)
        comment.body = new_body # keep in-memory copy in sync

        next if Notification.exists?(user: target, comment: comment)

        Notification.create!(
          user:    target,
          actor:   user,
          comment: comment,
          read:    false,
        )
        notification_count += 1
      end
    end
    log "  ✓ #{notification_count} notifications"
  end

  # ── Step 5: Meilisearch bulk reindex ─────────────────────────────────────
  def reindex_meilisearch
    log "Triggering Meilisearch reindex…"
    Comment.ms_reindex!
    log "  ✓ Reindex queued (processed by Sidekiq)"
  rescue StandardError => e
    log "  ⚠ Meilisearch reindex failed: #{e.message}"
  end

  # ── Summary ────────────────────────────────────────────────────────────────
  def print_summary
    puts
    puts "┌─────────────────────────────────────────────┐"
    puts "│  Seed complete                              │"
    puts "├─────────────────────────────────────────────┤"
    puts "│  Users          #{User.count.to_s.ljust(28)} │"
    puts "│  Root comments  #{@root_comments.size.to_s.ljust(28)} │"
    puts "│  Subcomments    #{@subcomments.size.to_s.ljust(28)} │"
    puts "│  Notifications  #{Notification.count.to_s.ljust(28)} │"
    puts "└─────────────────────────────────────────────┘"
    puts "  All passwords: password123"
    puts
  end

  def log(msg)
    puts msg
  end
end

# ─────────────────────────────────────────────────────────────────────────────
# Rake task
# ─────────────────────────────────────────────────────────────────────────────
namespace :db do
  namespace :seed do
    desc <<~DESC
      Generate test data with configurable parameters.

      Parameters (positional):
        users_count          – number of users to create                      (default: 10)
        comments_per_user    – root comments each user writes                 (default:  5)
        mentions_per_user    – @mention events per user across their comments (default:  3)
        subcomments_per_user – depth-1 replies per user on other users roots  (default:  4)

      Usage:
        bundle exec rake "db:seed:generate[10,5,3,4]"
        bundle exec rake  db:seed:generate            # uses all defaults
    DESC
    task :generate,
         %i[users_count comments_per_user mentions_per_user subcomments_per_user] => :environment do |_t, args|

      users_count          = (args[:users_count]          || 10).to_i
      comments_per_user    = (args[:comments_per_user]    ||  5).to_i
      mentions_per_user    = (args[:mentions_per_user]    ||  3).to_i
      subcomments_per_user = (args[:subcomments_per_user] ||  4).to_i

      puts
      puts "Parameters:"
      puts "  users_count:          #{users_count}"
      puts "  comments_per_user:    #{comments_per_user}"
      puts "  mentions_per_user:    #{mentions_per_user}"
      puts "  subcomments_per_user: #{subcomments_per_user}"
      puts "  estimated comments:   #{users_count * (comments_per_user + subcomments_per_user)}"
      puts

      SeedDataGenerator.new(
        users_count:,
        comments_per_user:,
        mentions_per_user:,
        subcomments_per_user:,
      ).run
    end
  end
end
