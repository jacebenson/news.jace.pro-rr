# news.jace.pro Migration Plan: CedarJS to Ruby on Rails

## Overview

Migrating a ServiceNow news aggregation platform from CedarJS (RedwoodJS fork) to Ruby on Rails with SQLite and Tailwind CSS.

**Current Stack:** CedarJS, React 18.3, GraphQL, Prisma, SQLite, Tailwind CSS
**Target Stack:** Ruby on Rails 8, SQLite, Hotwire (Turbo + Stimulus), Tailwind CSS

## Database Stats (from 2026-01-31.db)

### Primary Tables
| Table | Records |
|-------|---------|
| NewsItem | 50,409 |
| Participant | 5,507 |
| KnowledgeSession | 4,414 |
| Company | 3,956 |
| ServiceNowStoreApp | 3,487 |
| ServiceNowPartner | 3,487 (legacy, migrating to Company) |
| Tag | 1,851 |
| ServiceNowCustomer | 1,015 (legacy, migrating to Company) |
| NewsFeed | 178 |
| User | 66 |

### Join/Relationship Tables
| Table | Records | Description |
|-------|---------|-------------|
| NewsItemParticipant | 24,973 | Links news items to mentioned participants |
| NewsItemTag | 9,360 | Links news items to tags |
| KnowledgeSessionParticipant | 6,799 | Links Knowledge sessions to speakers |
| KnowledgeSessionList | 141 | User's saved/bookmarked sessions |

### Participant → Company Links
Participants have a `companyId` foreign key linking them to companies.
- 3,432 participants linked to a company
- 2 participants linked to a user (claimed profiles)

### NewsItem → NewsFeed Links
- 48,598 news items linked to a feed (96% of items)

## Data Model

### Core Models

```
User
  - email, hashed_password, salt, name, link, roles (default: 'user')
  - has_many :knowledge_session_lists
  - has_many :participants (claimed profiles)

NewsFeed
  - title, active, status ('active'|'paused'|'dead'|'error'), notes
  - image_url, url, default_author, type ('rss'|'scrape'|'youtube search'|'collection')
  - fetch_url, last_successful_fetch, last_error, error_count
  - has_many :news_items

NewsItem
  - type ('article'|'video'|'audio'|'event'|'pdf'|'post')
  - active, state ('new'|'enriched'|...)
  - title, body, url (unique), image_url, duration
  - published_at, event_start, event_end, event_location
  - ad_url, call_to_action
  - belongs_to :news_feed (optional)
  - has_many :news_item_participants -> :participants
  - has_many :news_item_tags -> :tags

Participant
  - name (unique), alias, company, title, bio
  - image_url, linkedin_url
  - belongs_to :company (optional)
  - belongs_to :user (optional - claimed profile)
  - has_many :news_item_participants -> :news_items
  - has_many :knowledge_session_participants -> :knowledge_sessions

Tag
  - name (unique)
  - has_many :news_item_tags -> :news_items

Company (unified model replacing ServiceNowPartner + ServiceNowCustomer)
  - name (unique), alias (JSON array), active
  - is_customer, is_partner
  - website, image_url, notes
  - city, state, country
  - Partner fields: build_level, consulting_level, reseller_level, etc.
  - rss_feed_url, servicenow_url, servicenow_page_url
  - products (JSON), services (JSON)
  - has_many :participants

KnowledgeSession
  - code, session_id (unique), title, title_sort, abstract
  - published, modified, event_id, recording_url
  - participants (JSON), times (JSON)
  - has_many :knowledge_session_participants -> :participants
  - has_many :knowledge_session_lists -> :users

ServiceNowStoreApp
  - source_app_id (unique), title, tagline, store_description
  - company_name, company_logo, logo
  - app_type, app_sub_type, version, versions_data (JSON)
  - purchase_count, review_count, table_count
  - key_features, business_challenge, system_requirements
  - Various allow_* boolean flags
  - supporting_media (JSON), support_links (JSON), support_contacts (JSON)

ServiceNowInvestment
  - type, content, summary, url
  - amount, currency, date
  - people, company
```

### Join Tables
- NewsItemParticipant (news_item_id, participant_id)
- NewsItemTag (news_item_id, tag_id)
- KnowledgeSessionParticipant (knowledge_session_id, participant_id)
- KnowledgeSessionList (knowledge_session_id, user_id) - user's saved sessions

## Routes / Features

### Public Pages
| Route | Description |
|-------|-------------|
| `/` | Redirect to /i |
| `/i` | News feed (paginated, searchable) |
| `/i/search/:term` | Search news items |
| `/i/participant/:name` | News by participant |
| `/p` | Partners directory (filterable by product/service/location) |
| `/p/search/:term` | Search partners |
| `/a` | ServiceNow Store apps (auth required) |
| `/a/search/:term` | Search apps |
| `/a/company/:name` | Apps by company |
| `/who/:slug` | Participant profile page |
| `/k20` - `/k26` | Knowledge conference sessions by year |
| `/k25/search/:term` | Search K25 sessions |
| `/k25/tags/:tags` | Filter K25 by tags |
| `/k25/list/:list` | User's saved K25 sessions |
| `/nulledge25` | nullEDGE 25 sessions |
| `/login`, `/signup`, `/forgot-password`, `/reset-password` | Auth |
| `/:slug` | Dynamic slug page |

### Admin Pages (role: admin)
| Route | Description |
|-------|-------------|
| `/admin` | Dashboard |
| `/admin/news-items` | Manage news items |
| `/admin/news-feeds` | Manage RSS feeds |
| `/admin/participants` | Manage participants |
| `/admin/companies` | Manage companies (unified partners/customers) |
| `/admin/store-apps` | Manage ServiceNow Store apps |
| `/admin/knowledge-sessions` | Manage Knowledge sessions |
| `/admin/users` | Manage users |
| `/admin/background-jobs` | View job queue |
| `/admin/investments` | Manage investments |

### User Pages (authenticated)
| Route | Description |
|-------|-------------|
| `/account` | User account settings |

## Background Jobs

| Job | Purpose | Schedule |
|-----|---------|----------|
| FetchNewsItemsJob | Fetch RSS/scrape/YouTube feeds | Every hour |
| EnrichItemJob | AI enrichment of news items | After fetch |
| FetchAppsJob | Sync ServiceNow Store apps | TBD |
| FetchPartnersJob | Sync partner directory | TBD |
| EnrichPartnersJob | Enrich partner data | TBD |
| ExtractVideoParticipantsJob | Extract participants from videos | On new video |
| ProcessParticipantImageJob | Process/resize participant images | On upload |
| LinkParticipantsJob | Link participants to companies | TBD |
| K25eventsJob / K26eventsJob | Sync Knowledge sessions | TBD |
| FetchRainfocusEventsJob | Fetch from Rainfocus API | TBD |
| FetchSECFilingsJob | Fetch SEC filings | TBD |
| BackupJob | Database backup | TBD |

## Migration Strategy

### Phase 1: Foundation
1. Create Rails 8 app with SQLite, Tailwind, Hotwire
2. Set up authentication (Devise or custom bcrypt)
3. Create all models and migrations
4. Set up Active Storage for images

### Phase 2: Data Migration
1. Write migration script to import from existing SQLite
2. Migrate all primary tables preserving IDs and relationships
3. Migrate all join tables:
   - NewsItemParticipant (24,973 records)
   - NewsItemTag (9,360 records)
   - KnowledgeSessionParticipant (6,799 records)
   - KnowledgeSessionList (141 records)
4. Migrate Participant → Company relationships (companyId foreign keys)
5. Merge ServiceNowPartner + ServiceNowCustomer into Company
6. Validate data integrity and relationship counts

### Phase 3: Public Pages
1. News feed (`/i`) with pagination and search
2. Partners directory (`/p`) with filters
3. Participant profiles (`/who/:slug`)
4. Knowledge sessions (K20-K26, nullEDGE)
5. Store apps (`/a`) - requires auth

### Phase 4: Admin Pages
1. Admin dashboard
2. CRUD for all models
3. Custom admin views with filters/search

### Phase 5: Background Jobs
1. Set up Solid Queue (Rails 8 default)
2. Port FetchNewsItemsJob (RSS parsing)
3. Port EnrichItemJob (OpenAI integration)
4. Port remaining jobs as needed

### Phase 6: Polish
1. SEO meta tags
2. RSS feed output (`/rss`)
3. Performance optimization
4. Deploy to Coolify

## Technical Decisions

### Why Rails?
- Simpler deployment (single process)
- Built-in background jobs (Solid Queue)
- SQLite first-class support in Rails 8
- Faster development with conventions
- No GraphQL complexity

### Hotwire vs React
- Turbo for navigation and forms
- Stimulus for interactivity
- ViewComponents for reusable UI
- Much simpler than React + GraphQL

### Authentication
- Use `has_secure_password` (built-in bcrypt)
- Session-based auth (simpler than JWT)
- Role-based authorization

### Styling
- Tailwind CSS (same as current)
- Keep existing class names where possible

## File Structure

```
app/
  controllers/
    application_controller.rb
    news_items_controller.rb
    partners_controller.rb (companies with is_partner)
    participants_controller.rb
    knowledge_sessions_controller.rb
    store_apps_controller.rb
    sessions_controller.rb (auth)
    admin/
      base_controller.rb
      news_items_controller.rb
      news_feeds_controller.rb
      companies_controller.rb
      participants_controller.rb
      ...
  models/
    user.rb
    news_feed.rb
    news_item.rb
    participant.rb
    company.rb
    knowledge_session.rb
    servicenow_store_app.rb
    ...
  views/
    layouts/
    news_items/
    partners/
    participants/
    knowledge_sessions/
    admin/
  jobs/
    fetch_news_items_job.rb
    enrich_item_job.rb
    ...
  components/ (ViewComponents)
config/
  routes.rb
db/
  migrate/
  seeds.rb
  schema.rb
```

## Commands to Start

```bash
# Create Rails app
rails new news.jace.pro-rr --database=sqlite3 --css=tailwind --skip-jbuilder

# Add gems
bundle add view_component
bundle add pagy  # pagination
bundle add rss   # RSS parsing
bundle add ruby-openai  # AI enrichment

# Generate models
rails g model User email:string:uniq hashed_password:string salt:string name:string roles:string
rails g model NewsFeed title:string active:boolean status:string type:string ...
# etc.

# Run migrations
rails db:migrate

# Import data
rails db:seed  # or custom import task
```

## Open Questions

1. **RSS Feed Output**: Keep `/rss` endpoint for news feed subscribers?
2. **API**: Need any JSON API endpoints or purely HTML?
3. **Image Storage**: Use Active Storage or keep external URLs (S3)?
4. **Search**: Full-text search needed? (SQLite FTS5 or pg_search later?)
5. **Real-time**: Any need for Action Cable / WebSockets?

## Timeline Estimate

- Phase 1 (Foundation): 2-3 hours
- Phase 2 (Data Migration): 1-2 hours
- Phase 3 (Public Pages): 4-6 hours
- Phase 4 (Admin Pages): 3-4 hours
- Phase 5 (Background Jobs): 3-4 hours
- Phase 6 (Polish): 2-3 hours

**Total: ~15-22 hours of development**

---

## Completion Status

### Phase 1: Foundation - COMPLETE
- Rails 8 app with SQLite, Tailwind CSS
- All models and migrations
- Custom bcrypt authentication

### Phase 2: Data Migration - COMPLETE
- 50,409 news items
- 5,507 participants
- 4,414 Knowledge sessions
- All relationships preserved

### Phase 3: Public Pages - COMPLETE
- `/i` - News items with pagination and search
- `/p` - Partners with filters (level, build, consulting, country)
- `/c` - Customers page
- `/a` - Store apps with search
- `/k20-k26`, `/nulledge25` - Knowledge sessions
- `/who/:slug` - Participant profiles
- Shareable session lists (`/k26/list/:user_id`)

### Phase 4: Admin Pages - COMPLETE
- Dashboard
- Users, Companies, Participants CRUD
- News Feeds, News Items CRUD
- Knowledge Sessions CRUD
- Store Apps, Investments CRUD
- Background Jobs with manual triggers

### Phase 5: Background Jobs - COMPLETE
- `FetchNewsItemsJob` - RSS feed fetching
- `FetchAppsJob` - ServiceNow Store app sync
- `EnrichItemJob` - Item enrichment
- Admin UI to trigger jobs manually

### Phase 6: Polish - IN PROGRESS
- [x] Favicon/logo
- [x] Tailwind-styled Kaminari pagination
- [x] Shareable session list URLs
- [ ] Deploy to production

---

## Remaining Tasks

1. **Deploy to Coolify** - Final deployment to production
2. **Test background jobs in production** - Verify Solid Queue works
3. **RSS feed output** - Optional: `/rss` endpoint for subscribers
