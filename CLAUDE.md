# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Social Portal: a multi-tenant content calendar and post-performance tracker for social media teams. Rails 8.1 / Ruby 3.2.2, PostgreSQL, Hotwire (Turbo + Stimulus) with importmaps (no Node build), Solid Queue/Cache/Cable, Active Storage. Instagram is the only platform with real publishing (Meta Graph API via Faraday); Facebook/LinkedIn/X/TikTok exist in schema and UI but mark themselves "manual publish".

The git repo root is this directory (`social-portal/`). The sibling `../backend template/` folder holds the raw Pixelstrap theme source and is not part of the app.

## Commands

```bash
bundle install
bin/rails db:create db:migrate db:seed   # seeds demo login: demo@socialportal.test / password123
bin/rails server                          # http://localhost:3000/login
bin/jobs                                  # Solid Queue worker (or SOLID_QUEUE_IN_PUMA=true bin/rails server)

bin/rails test                            # all tests (Minitest)
bin/rails test test/models/post_test.rb   # one file
bin/rails test test/models/post_test.rb:12  # one test by line
bin/rails test:system                     # Capybara/Selenium system tests

bin/rubocop                               # style (rubocop-rails-omakase)
bin/brakeman --no-pager                   # security static analysis
bin/bundler-audit                         # gem CVE audit
bin/importmap audit                       # JS dependency audit
```

CI (`.github/workflows/ci.yml`) runs brakeman, bundler-audit, importmap audit, rubocop, tests, and system tests.

Relevant ENV: `ANTHROPIC_API_KEY` / `OPENAI_API_KEY` (AI features; app works without them), `APP_HOST` (public tunnel URL in dev so Instagram can fetch media via `rails_blob_url`), `AWS_S3_BUCKET` + AWS creds (production Active Storage switches to S3 when set — see `config/environments/production.rb`).

## Architecture

### Tenancy and authorization

- `Company` is the tenant. `User` belongs to companies through `Membership` (roles: `owner`, `editor`, `viewer`/`member`). `users.admin` marks a **platform admin** who bypasses every gate and can act on all companies.
- Auth is hand-rolled (`has_secure_password`, no Devise): `SessionsController` + a `Session` model with a random token stored in a cookie. `app/controllers/concerns/authentication.rb` is included in `ApplicationController` and provides `current_user`, `current_company`, `current_membership`, `accessible_companies`, and the `can_manage_company?` / `can_publish_company?` gates. Use `allow_unauthenticated :action` to open an action.
- Almost every resource is nested under `/companies/:company_id/...` and companies are looked up **by slug**. `app/controllers/concerns/company_scoped.rb` loads `@company` and enforces membership — include it in any new company-nested controller and scope all queries through `@company`.
- Public signup is intentionally disabled; users are created from a company's Users page by admins/owners.

### Post lifecycle and publishing

- `Post` status flow: `draft → pending_review → approved → scheduled → publishing → published`, with `partial_failure` / `failed` outcomes. Transitions are bang methods on `Post` (`submit_for_review!`, `approve!`, `schedule!`, …) triggered by member routes on `PostsController`. `STATUSES` string constants are used everywhere (no enums).
- Approval is content-bound: editing caption/hashtags/media of an approved or scheduled post reverts it to `pending_review` (`Post#revert_approval_on_content_change`). Workflow transitions are exempt because they change `status` explicitly — keep that invariant when adding save paths.
- A post targets channels through `ChannelPost` (join with its own per-channel status/external id/last error). `Posts::PublishJob` **claims** channel posts (`pending`/`failed`/`skipped` → `publishing`) inside `post.with_lock` so concurrent runs can't double-publish; each enqueued job is pinned to the `scheduled_at` it was created for via the `scheduled_for` arg, so rescheduling just enqueues a fresh job and stale ones no-op. `Posts::SweepOverdueJob` (recurring, every 5 min) recovers scheduled posts whose job was lost.
- Posts have a `post_type` (`post` / `reel` / `story`, `POST_TYPES`). `Post#publish_blockers` enforces the type/media rules (reel = exactly one video, story = exactly one attachment, media required when Instagram is targeted) and is checked in `schedule`/`publish_now` and again in the job. Stories don't require a caption (`validates :caption … unless: :story?`) — use `Post#display_title` in views, never `caption.truncate`.
- Instagram publishes through `Instagram::Client` per type: feed post (image, carousel for multiple attachments, Reels for a single video), reel (`publish_video`), story (`publish_story`, `media_type: STORIES`); every other platform is marked `skipped` with a "publish manually" note. `Metrics::FetchInstagramJob` requests a per-type metric set (reels: `plays` → `video_views`; stories: `replies` → `comments`; no `impressions` for reels). Aggregate status treats `skipped` as neutral: `partial_failure`/`failed` mean real errors. Transient Meta errors (`Instagram::Client::TransientError`: 5xx/429/network) retry via `retry_on`; permanent `Error`s fail the channel immediately. After any success, `Metrics::FetchInstagramJob` runs 30 minutes later to snapshot insights into `PostMetric` rows.
- Published `ChannelPost` rows are protected: `PostsController#update` re-adds their channel ids no matter what the form submits (removing one would cascade-delete metric history).
- `SocialChannel#supports_auto_publish?` (instagram + token + external account id) is the switch between auto-publish and manual badges in the UI. `access_token` is encrypted (`encrypts`); keys are in credentials under `active_record_encryption`, overridable via `ACTIVE_RECORD_ENCRYPTION_*` ENV (see `config/initializers/active_record_encryption.rb`).
- Instagram needs a **publicly reachable** media URL at publish time — `APP_HOST` must be set (a tunnel locally); the job fails the channel with a clear error if it isn't.

### AI services

- `app/services/ai/` — `Ai::CaptionGenerator` and `Ai::ImageGenerator` sit on top of provider adapters in `ai/providers/` (`anthropic.rb`, `openai.rb`, `openai_images.rb`). The provider registry lives in `Ai::Providers`; errors are `Ai::Error` / `Ai::NotConfigured` (missing key degrades to a "not configured" message, never a crash).
- Provider/model/image-quality are **global** (all tenants), stored in the singleton `AppSetting.current` and edited at `/ai_settings`. Image generation is always OpenAI regardless of the caption provider.

### Frontend / theme

- Pixelstrap "viho" Bootstrap 5 admin theme is served statically from `public/theme/`. Layouts load only the per-page CSS/JS subset via the `_theme_head` / `_theme_scripts` partials in `app/views/layouts/` (FullCalendar, Chart.js, Feather icons, etc.) — when adding a page that needs a theme asset, wire it through those partials rather than a global include.
- Two layouts: `application` (signed-in shell with sidebar/header) and `auth` (login).

### Conventions

- Status/platform display metadata (labels, hex colors, icon classes) lives as hash-lookup methods on the models themselves (`Post#status_color`, `SocialChannel#platform_label`, …) — follow that pattern for new statuses/platforms.
- Jobs are namespaced by domain (`Posts::PublishJob`, `Metrics::FetchInstagramJob`) under `app/jobs/posts/` and `app/jobs/metrics/`.

## Roadmap items intentionally not built

Real LinkedIn/Facebook/X publishing, Instagram OAuth (tokens are pasted manually), recurring metric refresh cron, comment monitoring, Slack failure notifications. Don't "fix" the skipped-platform behavior in `Posts::PublishJob` unless asked to implement one of these.
