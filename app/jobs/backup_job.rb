class BackupJob < ApplicationJob
  queue_as :default

  # Backup SQLite database to S3
  # Only runs if ENABLE_BACKUP=true
  # Can be tested manually with: BackupJob.new.backup_database(dry_run: true)

  def perform(force: false)
    Rails.logger.info "[BACKUP] Starting BackupJob"

    # Check if backup is enabled
    unless force || backup_enabled?
      Rails.logger.info "[BACKUP] Skipped: ENABLE_BACKUP is not 'true'"
      schedule_next_run
      return { skipped: true, reason: "ENABLE_BACKUP not true" }
    end

    # Verify S3 is configured
    unless S3Service.enabled? && ENV["S3_BUCKET"].present?
      Rails.logger.error "[BACKUP] S3 not configured for backups"
      return { error: "S3 not configured" }
    end

    result = backup_database
    schedule_next_run if backup_enabled?
    result
  end

  # Public method for testing - can be called directly
  # BackupJob.new.backup_database(dry_run: true)
  def backup_database(dry_run: false)
    db_path = database_path
    backup_filename = "#{Date.current.iso8601}.db"
    backup_path = Rails.root.join("storage", backup_filename)

    Rails.logger.info "[BACKUP] Database: #{db_path}"
    Rails.logger.info "[BACKUP] Backup file: #{backup_path}"

    if dry_run
      Rails.logger.info "[BACKUP] DRY RUN - would backup to: #{backup_filename}"
      return { dry_run: true, backup_filename: backup_filename, db_path: db_path }
    end

    # Check if backup already exists locally
    if File.exist?(backup_path)
      Rails.logger.info "[BACKUP] Local backup already exists: #{backup_path}"
    else
      # Create backup using SQLite's .backup command
      create_local_backup(db_path, backup_path)
    end

    return { error: "Local backup failed" } unless File.exist?(backup_path)

    # Upload to S3
    uploaded = upload_to_s3(backup_path, backup_filename)

    if uploaded
      # Clean up local backup file
      File.delete(backup_path)
      Rails.logger.info "[BACKUP] Local backup cleaned up"
      { success: true, backup_filename: backup_filename, size: File.size?(backup_path) || "unknown" }
    else
      { error: "S3 upload failed" }
    end
  end

  private

  def backup_enabled?
    ENV["ENABLE_BACKUP"]&.downcase == "true"
  end

  def database_path
    # Get the database path from the configuration
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    db_path = config[:database]

    # Handle relative paths
    if db_path && !db_path.start_with?("/")
      db_path = Rails.root.join(db_path).to_s
    end

    db_path
  end

  def create_local_backup(db_path, backup_path)
    Rails.logger.info "[BACKUP] Creating local backup..."

    # Check sqlite3 is available
    sqlite_version = `sqlite3 --version 2>&1`.strip
    Rails.logger.info "[BACKUP] SQLite version: #{sqlite_version}"

    # Use SQLite's .backup command which works even with active connections
    # .timeout 30000 = wait up to 30 seconds if database is locked
    command = %Q(sqlite3 "#{db_path}" ".timeout 30000" ".backup '#{backup_path}'")
    Rails.logger.info "[BACKUP] Running: #{command}"

    result = system(command)

    if result && File.exist?(backup_path)
      size_mb = (File.size(backup_path) / 1024.0 / 1024.0).round(2)
      Rails.logger.info "[BACKUP] Local backup created: #{size_mb} MB"
      true
    else
      Rails.logger.error "[BACKUP] Failed to create local backup"
      false
    end
  end

  def upload_to_s3(backup_path, backup_filename)
    bucket = ENV["S3_BUCKET"]
    Rails.logger.info "[BACKUP] Uploading to S3: #{bucket}/#{backup_filename}"

    S3Service.upload_backup(file_path: backup_path.to_s, key: backup_filename)
  end

  def schedule_next_run
    # Run again in 1 day
    BackupJob.set(wait: 1.day).perform_later
  end
end
