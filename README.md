# Social Portal

A multi-tenant content calendar and post-performance tracker for social media teams. Plan, review, approve, schedule, and publish posts across Instagram, Facebook, LinkedIn, X (Twitter), and TikTok — and watch how each post performs after going live.

This first cut wires up real Instagram publishing via the Meta Graph API. Other platforms are modeled in the schema and the UI but currently mark themselves as "manual publish" until their integrations are filled in.

## Stack

- Rails 8.1, Ruby 3.2.2
- PostgreSQL (development & test) — Solid Queue / Solid Cache / Solid Cable
- Importmap + Hotwire (Turbo, Stimulus)
- Active Storage for post media
- Faraday + Instagram Graph API for publishing & insights
- Bootstrap 5 admin theme served from `public/theme/`

## Setup

```bash
cd social-portal
bundle install
bin/rails db:create db:migrate db:seed
bin/rails server
```

Then sign in at http://localhost:3000/login with:

```
demo@socialportal.test / password123
```

## Demo data

`db/seeds.rb` creates:

- A demo company (`Kamagram`)
- Two users: `demo@socialportal.test` (owner) and `editor@socialportal.test` (editor) — both with password `password123`
- Three connected channels: Instagram, LinkedIn, X
- Six posts across all status states (`draft → pending_review → approved → scheduled → published`), with metric snapshots over time on the published ones

## Concepts

| Model           | Role |
|-----------------|------|
| `Company`       | Tenant. Owns channels, posts, and analytics. |
| `User`          | Person. Logs in. Belongs to many companies via `Membership`. |
| `Membership`    | Join. Roles: `owner`, `admin`, `editor`, `viewer`, `member`. |
| `SocialChannel` | A connected social account (Instagram, LinkedIn, etc). Stores access tokens. |
| `Post`          | A single piece of content authored under a company. Has many channels via `ChannelPost`. Has many media attachments via Active Storage. |
| `ChannelPost`   | Per-channel publishing record: status, external id, external url, last error. |
| `PostMetric`    | A timestamped snapshot of likes, comments, shares, saves, reach, impressions, engagement rate for a `ChannelPost`. |

## Workflow

```
draft → pending_review → approved → scheduled → published
                                                 ↘ partial_failure / failed
```

Each transition is a button on the post detail page. Schedule enqueues a `Posts::PublishJob` via Solid Queue. After publishing, a `Metrics::FetchInstagramJob` is queued 30 minutes later to snapshot insights.

## Connecting Instagram (real publishing)

Real publishing requires:

1. A Facebook Page connected to a Business Instagram account.
2. A Meta App with the **Instagram Graph API** product enabled.
3. A long-lived **Page access token** with these permissions:
   - `instagram_basic`
   - `instagram_content_publish`
   - `pages_read_engagement`
   - `pages_show_list`
4. The **Instagram Business Account ID** (numeric, e.g. `17841...`).

Steps:

1. Sign in to the portal, open your company, go to **Channels**, click **Connect channel**.
2. Choose **Instagram**, paste your handle, the Business Account ID, and the long-lived access token.
3. Save. The badge will switch to **Auto-publish ready**.

Then, when scheduling or hitting "Publish now":

- Image posts: works out of the box for any post with at least one image attachment.
- Video posts: supported via the Reels container flow (`media_type: REELS`).

### Public media URLs

Instagram requires the image/video URL be **publicly reachable**. In development, set:

```bash
APP_HOST=https://your-ngrok-or-tunnel-url
```

before running the server, so `rails_blob_url` resolves to a URL Meta can fetch.

In production, mount Active Storage on a public bucket (S3, GCS) and the URL is generated automatically.

## Running background jobs

Solid Queue is included. For local dev:

```bash
bin/jobs
```

Or run the Rails server with `SOLID_QUEUE_IN_PUMA=true`:

```bash
SOLID_QUEUE_IN_PUMA=true bin/rails server
```

## Theme

The admin theme (Pixelstrap "viho", Bootstrap 5) is dropped into `public/theme/`. The `_theme_head` and `_theme_scripts` partials in `app/views/layouts/` load the small subset of CSS/JS each page needs (FullCalendar, Chart.js, Feather icons, Bootstrap, etc).

## Roadmap (intentionally not built yet)

- Real LinkedIn / Facebook Page / X publishing (the model and UI handle them; jobs need wiring).
- Instagram OAuth flow (right now tokens are pasted manually).
- Recurring metric refresh job (on a Solid Queue cron).
- Per-post comment monitoring.
- Slack notifications when a post fails.
