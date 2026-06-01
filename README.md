# CommentApp

A multi-user threaded commenting application built with Rails 8.1, Hotwire, and PostgreSQL. Users can write nested comments, mention others with `@username`, receive real-time notifications, and search comments via Meilisearch. The entire stack runs in Docker.

---

## Features

- **Threaded comments** — up to 3 levels deep (root → reply → reply-to-reply)
- **@username mentions** — create notifications for mentioned users; editing a comment adds/removes notifications correctly
- **Real-time UI** — comment CRUD, reply forms, and notification bell badge all update via Hotwire Turbo Streams without page reloads
- **In-place editing** — edit comments inside their own Turbo Frame; cancel restores the original
- **Notification centre** — mark individual or all notifications as read; bell badge decrements instantly
- **Full-text search** — powered by Meilisearch with async indexing via Sidekiq
- **My Comments** — per-user flat view with "View in context" link that scrolls and highlights the comment
- **Expand / Collapse** — per-comment tree and global feed expand/collapse buttons
- **ViewComponents** — all UI partials are encapsulated as Ruby-backed ViewComponent classes
- **Guest access** — root comments visible to everyone; subcomments, forms, and notifications require login

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Rails 8.1 |
| Language | Ruby 3.4 |
| Database | PostgreSQL 16 |
| Auth | Devise |
| CSS | Tailwind CSS v4 (tailwindcss-rails) |
| Realtime | Hotwire — Turbo Streams + Stimulus |
| UI components | ViewComponent 4 |
| Search | Meilisearch + meilisearch-rails |
| Background jobs | Sidekiq + Redis |
| Comment tree | ancestry gem |
| Testing | RSpec + FactoryBot + Capybara + Shoulda Matchers |
| Containers | Docker + Docker Compose |

---

## Architecture

### Service objects
All business logic lives in `app/services/`, not in controllers or models. Controllers call one service and respond. Each service inherits from `ApplicationService` and exposes `success?` and `errors`.

```
app/services/
  application_service.rb
  mention_notifier.rb
  comments/
    create.rb   update.rb   destroy.rb
  notifications/
    mark_as_read.rb   mark_all_as_read.rb
```

### ViewComponents
Every shared UI piece is a `ViewComponent::Base` subclass in `app/components/`. Templates are thin HTML; logic lives in Ruby methods on the component class.

```
app/components/
  application_component.rb        # base: includes Turbo::FramesHelper
  sidebar_component.rb/html.erb
  notification_badge_component.rb/html.erb
  notification_row_component.rb/html.erb
  comment_form_component.rb/html.erb
  reply_form_component.rb/html.erb
  comment_component.html.erb      # recursive — renders children
```

### Hotwire flow
- **Create comment** → `turbo_stream.prepend` to `#comments-list` (root) or `turbo_stream.append` to `#children-comment-N` (reply)
- **Edit comment** → edit form loads inside same `<turbo-frame id="comment-N">`; save replaces it in-place
- **Delete comment** → `turbo_stream.remove` the frame
- **Notification badge** → `turbo_stream.replace "notification_badge"` after mark-as-read

---

## Prerequisites

Only Docker and Docker Compose are required. No local Ruby, Node, or database installation needed.

---

## First Run

```bash
# 1. Clone and enter the app directory
cd comment_app

# 2. Copy environment config
cp .env.example .env

# 3. Build and start all services
docker compose up --build

# The app starts at http://localhost:3000
# On first boot it runs db:prepare and tailwindcss:build automatically
```

---

## Seed Data

Seeds create realistic users, threaded comments, and mention-based notifications. Parameters are at the top of `db/seeds.rb`:

| Parameter | Default | Description |
|---|---|---|
| `USERS_COUNT` | 10 | Number of users to create |
| `COMMENTS_PER_USER` | 5 | Root comments each user writes |
| `REPLIES_PER_COMMENT` | 3 | Depth-1 replies per root comment |
| `REPLIES_PER_REPLY` | 2 | Depth-2 replies per depth-1 reply |
| `MENTIONS_PER_USER` | 4 | @mention events per user across their comments |

```bash
docker compose run --rm app bundle exec rails db:seed
```

One test account is always created with known credentials:

| Email | Password |
|---|---|
| `tester@example.com` | `password123` |

The test account is guaranteed to have unread notifications waiting on first login.

---

## Verifying Scalability

To verify that pagination, infinite scroll, and full-text search work correctly at scale, use the data generator rake task to populate the database with a large realistic dataset.

```bash
docker compose run --rm app bundle exec rake "db:seed:generate[users,comments_per_user,mentions_per_user,subcomments_per_user]"
```

| Parameter | Description | Default |
|---|---|---|
| `users` | Number of random users to create (+ 2 reviewer accounts always added) | 10 |
| `comments_per_user` | Root comments each user writes | 5 |
| `mentions_per_user` | Times each user mentions other users across their comments | 3 |
| `subcomments_per_user` | Depth-1 replies each user makes on other users' root comments | 4 |

**Reviewer accounts**

Two accounts are always created regardless of the `users` parameter. Use these to log in immediately after seeding:

| Email | Password |
|---|---|
| `alice@example.com` | `password123` |
| `bob@example.com` | `password123` |

Open alice and bob in two separate browser windows (or normal + incognito) to test real-time notifications: post a comment as alice mentioning `@bob`, then check bob's bell badge update live.

**Example — generate ~30k comments:**

```bash
docker compose run --rm app bundle exec rake "db:seed:generate[200,100,5,50]"
# 202 users × (100 root + 50 subcomments) ≈ 30 000 comments
```

**Example — generate ~100k comments:**

```bash
docker compose run --rm app bundle exec rake "db:seed:generate[500,100,5,100]"
# 502 users × (100 root + 100 subcomments) ≈ 100 000 comments
```

**What to check after seeding:**

- Feed loads the first 50 root comments; scrolling down triggers automatic loading of the next batch
- Search returns results from the entire dataset, not just the loaded page (Meilisearch indexes everything in the background via Sidekiq — wait a few seconds after the task finishes before testing search)
- Notification bell counts and "My Comments" page remain fast regardless of total comment count

**Run with defaults:**

```bash
docker compose run --rm app bundle exec rake db:seed:generate
```

---

## Running Tests

Before the first run, create and migrate the test database:

```bash
docker compose run --rm -e RAILS_ENV=test app bundle exec rails db:create db:migrate
```

```bash
# All specs
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec

# By type
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/models
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/services
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/requests
docker compose run --rm -e RAILS_ENV=test app bundle exec rspec spec/system
```

> `-e RAILS_ENV=test` is required because the Docker service runs with `RAILS_ENV=development` by default. Without it, tests would run against the development database.

---

## Environment Variables

Copy `.env.example` to `.env` and fill in values before starting.

| Variable | Description |
|---|---|
| `DATABASE_URL` | Full PostgreSQL connection string |
| `REDIS_URL` | Redis connection URL for Sidekiq |
| `MEILISEARCH_URL` | Meilisearch instance URL |
| `MEILISEARCH_MASTER_KEY` | Meilisearch master API key |
| `RAILS_MASTER_KEY` | Rails credentials master key |
| `RAILS_ENV` | Environment (`development` / `production`) |

---

## Project Structure

```
app/
  components/       # ViewComponent classes + templates
  controllers/      # Thin: authenticate → call service → respond
  models/           # Validations, associations, scopes only
  services/         # One class per action, inherits ApplicationService
  views/            # Layouts, turbo stream templates, Devise views
  javascript/
    controllers/    # Stimulus: reply, expand/collapse, highlight
db/
  seeds.rb          # Configurable seed parameters at the top
spec/
  factories/        # FactoryBot factories
  models/           # Model unit specs
  services/         # Service unit specs
  requests/         # HTTP contract specs
  system/           # Capybara end-to-end specs
```

---

## Possible Further Improvements

1. **Infinite scroll for "My Comments" and Notifications** — apply the same cursor-based pagination used on the main feed so both pages stay fast at scale.
2. **User roles** — add an `admin / moderator / user` role enum to allow moderators to manage any comment and admins to manage users.
3. **Production readiness** — production Docker target with forced SSL, proper secret management, and a health-check endpoint.
4. **Frontend tests** — JavaScript unit tests (Vitest) for Stimulus controllers and Playwright end-to-end tests for live search and infinite scroll.
5. **Styled deletion confirmation** — replace the browser-native confirm dialog with a custom modal component.
6. **Auto-mark notifications as read** — mark a notification as read automatically when the linked comment scrolls into view.
7. **Two-factor authentication** — TOTP-based 2FA for an extra layer of account security.
8. **Admin panel** — protected dashboard for managing users, moderators, and viewing site-wide stats.
9. **Mobile-responsive UI** — adapt the layout and forms to work comfortably on small screens.
10. **Comment validation** — enforce length limits, reject blank-only input, and validate `@mention` format.
