# News.jace.pro (Rails)

A ServiceNow news aggregation platform built with Rails 8, SQLite, and Tailwind CSS. Aggregates content from RSS feeds, the ServiceNow Store, Partner Portal, SEC filings, and Knowledge conference archives.

## Tech Stack

- **Ruby 3.4** / **Rails 8**
- **SQLite** with SolidQueue for background jobs
- **Tailwind CSS** for styling
- **S3** (Hetzner Object Storage) for images and backups
- **Coolify** for deployment

## Getting Started

```bash
# Install dependencies
bundle install

# Setup database
bin/rails db:setup

# Run the server (includes SolidQueue workers)
bin/dev
```

## Environment Variables

```bash
# Required for production
RAILS_MASTER_KEY=xxx
SECRET_KEY_BASE=xxx

# Background jobs (run workers inside Puma)
SOLID_QUEUE_IN_PUMA=true

# AI enrichment (at least one required for AI features)
OPENAI_API_KEY=sk-xxx
GEMINI_API_KEY=xxx

# S3 Storage (Hetzner Object Storage)
S3_HOSTNAME=hel1.your-objectstorage.com
AWS_ACCESS_KEY_ID=xxx
AWS_SECRET_ACCESS_KEY=xxx
S3_BUCKET=news-jace-pro           # For backups
S3_ASSET_BUCKET=news-jace-pro-assets  # For images

# Optional
ENABLE_BACKUP=true  # Enable scheduled backups
```

## Background Jobs

All jobs can be triggered from the admin panel at `/admin/background_jobs` or via Rails console:

| Job | Purpose | Schedule |
|-----|---------|----------|
| `FetchNewsItemsJob` | Fetches RSS feeds | Every hour |
| `FetchAppsJob` | Fetches ServiceNow Store apps | Daily (~1 hour) |
| `EnrichItemJob` | AI enrichment, image uploads | Continuous |
| `FetchPartnersJob` | ServiceNow Partner Portal API | Weekly |
| `EnrichPartnersJob` | Discover logos, RSS, content | As needed |
| `LinkParticipantsJob` | Link participants to companies | After imports |
| `ExtractVideoParticipantsJob` | Extract speakers from videos | As needed |
| `FetchSecFilingsJob` | SEC EDGAR filings (10-K, etc) | Weekly |
| `BackupJob` | SQLite backup to S3 | Daily (if enabled) |

## Common Commands

### Rails Console

```ruby
# Run a job immediately
FetchNewsItemsJob.perform_now
EnrichItemJob.perform_now
BackupJob.perform_now(force: true)

# Check job queue status
SolidQueue::Job.where(finished_at: nil).count
SolidQueue::FailedExecution.count

# Retry failed jobs
SolidQueue::FailedExecution.find_each { |f| f.job.retry }

# Clear failed jobs
SolidQueue::FailedExecution.delete_all

# Database stats
NewsItem.count
NewsItem.where(state: 'new').count  # Pending enrichment
ServicenowStoreApp.count
Company.where(is_partner: true).count
Participant.where(company_id: nil).count  # Unlinked
```

### Useful Queries

```ruby
# Recent news items
NewsItem.order(created_at: :desc).limit(10).pluck(:title, :created_at)

# Items by type
NewsItem.group(:item_type).count

# Feeds with errors
NewsFeed.where.not(last_error: nil).pluck(:title, :last_error)

# Partners with RSS feeds
Company.where(is_partner: true).where.not(rss_feed_url: nil).count

# Store apps by company
ServicenowStoreApp.group(:company_name).count.sort_by(&:last).reverse.first(10)

# Knowledge sessions by year
KnowledgeSession.group(:year).count
```

### Data Import

```bash
# Import from CedarJS backup
bin/rails runner scripts/merge_feb8_backup.rb

# Then link participants to companies
bin/rails runner 'LinkParticipantsJob.perform_now'
```

### Database Management

```bash
# Backup locally
cp storage/production.sqlite3 storage/backup-$(date +%Y%m%d).sqlite3

# Open SQLite directly
sqlite3 storage/production.sqlite3

# Vacuum (reclaim space)
bin/rails runner 'ActiveRecord::Base.connection.execute("VACUUM")'
```

## Admin Routes

- `/admin` - Dashboard with stats
- `/admin/background_jobs` - Job management
- `/admin/news_items` - Manage news items
- `/admin/news_feeds` - Manage RSS feeds
- `/admin/participants` - Manage speakers/people
- `/admin/companies` - Manage companies
- `/admin/knowledge_sessions` - Knowledge conference sessions
- `/admin/servicenow_store_apps` - Store apps
- `/admin/sec_filings` - SEC filings

## Public Routes

- `/i` - News items (filterable by type)
- `/p/:id` - Participant profile
- `/c/:id` - Company profile
- `/a/:id` - Store app details
- `/k20` - `/k26` - Knowledge conference sessions
- `/who/:name` - Participant lookup by name

## Deployment (Coolify)

The app is deployed to Coolify at `newsrails.jace.pro`. Key settings:

- **Dockerfile**: Uses multi-stage build with `SOLID_QUEUE_IN_PUMA=true`
- **Persistent Storage**: `/rails/storage` mounted for SQLite database
- **Health Check**: `GET /up`

### Deploy Commands

```bash
# Push triggers auto-deploy
git push origin master

# SSH to server for debugging
ssh root@chonky.jace.pro
docker exec -it <container> bin/rails console
```

## Architecture Notes

- **Timestamps**: Stored as Unix milliseconds in source DB, converted with `ms_to_time()` helper
- **JSON Fields**: `alias`, `products`, `services`, `participants`, `times` stored as JSON strings
- **Type Column**: Renamed to `item_type`/`feed_type` to avoid Rails STI conflicts
- **Session Variable**: Use `ksession` instead of `session` in views (conflicts with Rails helper)

## License

MIT
