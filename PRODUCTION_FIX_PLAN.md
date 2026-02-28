# Production Data Fix Plan for Store App Duplicates

## Problem Summary

The ServiceNow Store app data has duplicate records because:
1. **Old records** stored `listing_id` in the `source_app_id` field (wrong)
2. **Full fetch** creates new records with correct `source_app_id` 
3. Result: Same app has 2 records with different IDs

### Current State (Local Dev)
- Total apps: 3,513
- With `listing_id`: 2,598 (74%)
- Missing `listing_id`: 915 (26%) - likely delisted or have wrong IDs
- Duplicate titles: 5 (different versions, legitimate)

## Key ID Fields

| Field | Purpose | Example |
|-------|---------|---------|
| `source_app_id` | API ID to fetch app details | `ae99d84b2320330006c0110d96bf65b3` |
| `listing_id` | ID for store URLs (`store.servicenow.com/store/app/{id}`) | `22196b6e1be06a50a85b16db234bcbbd` |

## Production Fix Steps

### Option A: Full Database Sync (Recommended)

Replace production database with local (already fixed) database.

```bash
# 1. On local machine - copy the fixed database
scp storage/production.sqlite3 root@chonky.jace.pro:/data/coolify/storage/newsrails/production.sqlite3.new

# 2. SSH to production server
ssh root@chonky.jace.pro

# 3. Stop the app
docker stop $(docker ps -q --filter "name=newsrails")

# 4. Backup existing database
cd /data/coolify/storage/newsrails
cp production.sqlite3 production.sqlite3.backup.$(date +%Y%m%d)

# 5. Replace with fixed database
mv production.sqlite3.new production.sqlite3

# 6. Restart the app (via Coolify UI or)
docker start $(docker ps -aq --filter "name=newsrails")
```

### Option B: Run Fix Script in Production

If you want to fix production database in-place:

```bash
# 1. SSH to production
ssh root@chonky.jace.pro

# 2. Get container ID
CONTAINER=$(docker ps -q --filter "name=newsrails")

# 3. Run the fix task
docker exec -it $CONTAINER bin/rails fix_duplicates:stats
docker exec -it $CONTAINER bin/rails fix_duplicates:all
docker exec -it $CONTAINER bin/rails fix_duplicates:fetch

# Note: fetch takes ~1 hour (3000+ apps, 1s delay each)
```

### Option C: Deploy Code, Trigger Fetch via Admin UI

1. Push code to master (triggers auto-deploy)
2. Wait for deploy to complete
3. Go to https://news.jace.pro/admin/background_jobs
4. Click "Run FetchAppsJob" 
5. This will fix duplicates automatically as it runs

## Verification

After fix, check stats:

```bash
docker exec -it $CONTAINER bin/rails fix_duplicates:stats
```

Expected output:
- Duplicate titles: ~5 (legitimate different versions)
- Missing listing_id: ~900 (delisted/internal apps - expected)

## Files Changed

- `app/jobs/fetch_apps_job.rb` - Fixed cookie parsing, added `listing_id` support
- `lib/tasks/fix_store_app_duplicates.rake` - New rake task for fixing duplicates
- `db/migrate/*_add_listing_id_*` - New columns

## Rollback Plan

If something goes wrong:

```bash
# Restore backup
ssh root@chonky.jace.pro
cd /data/coolify/storage/newsrails
docker stop $(docker ps -q --filter "name=newsrails")
cp production.sqlite3.backup.YYYYMMDD production.sqlite3
docker start $(docker ps -aq --filter "name=newsrails")
```
