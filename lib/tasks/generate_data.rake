# frozen_string_literal: true

# ─────────────────────────────────────────────────────────────────────────────
# Internal generator class — keeps the rake task body thin.
# ─────────────────────────────────────────────────────────────────────────────
class SeedDataGenerator
  # Two named reviewer accounts always created alongside random users.
  # Credentials are printed at the end so any reviewer can log in immediately.
  REVIEWER_ACCOUNTS = [
    { username: 'alice', email: 'alice@example.com', password: 'password123' },
    { username: 'bob',   email: 'bob@example.com',   password: 'password123' },
  ].freeze

  CHARACTER_SOURCES = [
    -> { Faker::TvShows::GameOfThrones.character },
    -> { Faker::Movies::LordOfTheRings.character },
  ].freeze

  QUOTE_SOURCES = [
    -> { Faker::TvShows::GameOfThrones.quote },
    -> { Faker::Movies::LordOfTheRings.quote },
  ].freeze

  def initialize(users_count:, comments_per_user:, mentions_per_user:, subcomments_per_user:)
    @users_count          = users_count
    @comments_per_user    = comments_per_user
    @mentions_per_user    = mentions_per_user
    @subcomments_per_user = subcomments_per_user
  end

  def run
    @reviewer_users = create_reviewer_users
    @users          = create_random_users
    @all_users      = @reviewer_users + @users
    @root_comments  = create_root_comments
    @subcomments    = create_subcomments
    create_mentions
    guarantee_reviewer_notifications
    reindex_meilisearch
    print_summary
  end

  private

  # ── Step 1: named reviewer accounts ───────────────────────────────────────
  def create_reviewer_users
    log "Creating reviewer accounts…"
    users = REVIEWER_ACCOUNTS.map do |attrs|
      User.find_or_create_by!(username: attrs[:username]) do |u|
        u.email    = attrs[:email]
        u.password = attrs[:password]
      end
    end
    log "  ✓ #{users.size} reviewer accounts (alice, bob)"
    users
  end

  # ── Step 2: random users ──────────────────────────────────────────────────
  def create_random_users
    log "Creating #{@users_count} users…"
    users = @users_count.times.map { create_fandom_user }
    log "  ✓ #{users.size} users"
    users
  end

  def create_fandom_user
    retries = 0
    begin
      username = fandom_username(retries.positive? ? rand(100..999) : nil)
      User.create!(
        username: username,
        email:    "#{username}@example.com",
        password: 'password123',
      )
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      retries += 1
      retry if retries < 20
      raise
    end
  end

  def fandom_username(suffix = nil)
    raw  = CHARACTER_SOURCES.sample.call
    base = raw.downcase
              .gsub("'", '')
              .gsub(/[^a-z0-9]+/, '_')
              .gsub(/\A_+|_+\z/, '')
              .slice(0, 25)
    suffix ? "#{base}_#{suffix}" : base
  rescue StandardError
    "user_#{SecureRandom.hex(4)}"
  end

  def fandom_quote
    QUOTE_SOURCES.sample.call
  rescue StandardError
    Faker::Lorem.paragraph(sentence_count: rand(1..3))
  end

  # ── Step 3: root comments ─────────────────────────────────────────────────
  def create_root_comments
    total = @all_users.size * @comments_per_user
    log "Creating #{total} root comments (#{@comments_per_user} per user)…"
    comments = []
    Comment.without_auto_index do
      @all_users.each do |user|
        @comments_per_user.times do
          comments << Comment.create!(body: fandom_quote, user: user)
        end
      end
    end
    log "  ✓ #{comments.size} root comments"
    comments
  end

  # ── Step 4: subcomments (depth-1 replies on other users' roots) ───────────
  def create_subcomments
    log "Creating subcomments (#{@subcomments_per_user} per user on other users' roots)…"
    subcomments = []
    Comment.without_auto_index do
      @all_users.each do |user|
        candidates = @root_comments.reject { |c| c.user_id == user.id }
        next if candidates.empty?

        candidates.sample([@subcomments_per_user, candidates.size].min).each do |root|
          subcomments << Comment.create!(body: fandom_quote, user: user, parent: root)
        end
      end
    end
    log "  ✓ #{subcomments.size} subcomments"
    subcomments
  end

  # ── Step 5: @mention events → notifications ───────────────────────────────
  def create_mentions
    log "Creating mentions (#{@mentions_per_user} per user)…"
    all_comments       = @root_comments + @subcomments
    notification_count = 0

    @all_users.each do |user|
      own_comments = all_comments.select { |c| c.user_id == user.id }
      next if own_comments.empty?

      other_users = @all_users.reject { |u| u.id == user.id }
      next if other_users.empty?

      @mentions_per_user.times do
        comment = own_comments.sample
        target  = other_users.sample
        mention = "@#{target.username}"
        next if comment.body.include?(mention)

        new_body = "#{comment.body} #{mention}"
        comment.update_columns(body: new_body)
        comment.body = new_body

        next if Notification.exists?(user: target, comment: comment)

        Notification.create!(user: target, actor: user, comment: comment, read: false)
        notification_count += 1
      end
    end
    log "  ✓ #{notification_count} notifications"
  end

  # ── Step 6: guarantee reviewer notifications ──────────────────────────────
  # Ensures alice and bob always have unread notifications waiting when they
  # first log in, regardless of how the random mention distribution fell.
  def guarantee_reviewer_notifications
    log "Guaranteeing notifications for reviewer accounts…"
    all_comments = @root_comments + @subcomments
    count        = 0

    @reviewer_users.each do |reviewer|
      # Pick 5 distinct random users to mention this reviewer
      mentioners = @users.sample([5, @users.size].min)
      mentioners.each do |actor|
        comment = all_comments.select { |c| c.user_id == actor.id }.sample
        next unless comment

        mention = "@#{reviewer.username}"
        next if comment.body.include?(mention)

        new_body = "#{comment.body} #{mention}"
        comment.update_columns(body: new_body)
        comment.body = new_body

        next if Notification.exists?(user: reviewer, comment: comment)

        Notification.create!(user: reviewer, actor: actor, comment: comment, read: false)
        count += 1
      end
    end

    log "  ✓ #{count} guaranteed notifications (alice + bob)"
  end

  # ── Step 7: Meilisearch bulk reindex ──────────────────────────────────────
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
    puts "┌─────────────────────────────────────────────────────────┐"
    puts "│  Seed complete                                          │"
    puts "├─────────────────────────────────────────────────────────┤"
    puts "│  Users (total)  #{User.count.to_s.ljust(40)} │"
    puts "│  Root comments  #{@root_comments.size.to_s.ljust(40)} │"
    puts "│  Subcomments    #{@subcomments.size.to_s.ljust(40)} │"
    puts "│  Notifications  #{Notification.count.to_s.ljust(40)} │"
    puts "├─────────────────────────────────────────────────────────┤"
    puts "│  Reviewer accounts — use these to log in and test:     │"
    puts "│                                                         │"
    REVIEWER_ACCOUNTS.each do |a|
      line = "  #{a[:email].ljust(28)}  #{a[:password]}"
      puts "│  #{line.ljust(55)} │"
    end
    puts "│                                                         │"
    puts "│  Tip: open alice and bob in two separate browsers to   │"
    puts "│  test mentions and real-time notifications.             │"
    puts "└─────────────────────────────────────────────────────────┘"
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
        users_count          – number of random users to create               (default: 10)
        comments_per_user    – root comments each user writes                 (default:  5)
        mentions_per_user    – @mention events per user across their comments (default:  3)
        subcomments_per_user – depth-1 replies per user on other users roots  (default:  4)

      Two named reviewer accounts (alice / bob) are always created in addition
      to the random users. Their credentials are printed at the end.

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
      puts "  users_count:          #{users_count} random + 2 reviewer accounts"
      puts "  comments_per_user:    #{comments_per_user}"
      puts "  mentions_per_user:    #{mentions_per_user}"
      puts "  subcomments_per_user: #{subcomments_per_user}"
      puts "  estimated comments:   #{(users_count + 2) * (comments_per_user + subcomments_per_user)}"
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
