#!/usr/bin/env ruby
# frozen_string_literal: true

# Load .env file if dotenv is available (development only)
begin
  require "dotenv"
  Dotenv.load
rescue LoadError
  # dotenv not installed, assume env vars are set manually
end

# Script to download the latest production database backup from S3
# Usage:
#   bin/rails runner scripts/download_prod_db.rb           # Downloads latest backup
#   bin/rails runner scripts/download_prod_db.rb 2025-04-01 # Downloads specific date
#   bin/rails runner scripts/download_prod_db.rb --list    # Lists recent backups

require "aws-sdk-s3"

class DownloadProdDb
  BACKUP_DIR = Rails.root.join("storage", "backups")

  def initialize(args = [])
    @args = args
  end

  def run
    check_s3_config!

    if list_mode?
      list_recent_backups
      return
    end

    backup_key = find_backup_key
    return unless backup_key

    download_backup(backup_key)
  end

  private

  def list_mode?
    @args.include?("--list") || @args.include?("-l")
  end

  def check_s3_config!
    missing = []
    missing << "S3_BUCKET" unless ENV["S3_BUCKET"].present?
    missing << "S3_HOSTNAME" unless ENV["S3_HOSTNAME"].present?
    missing << "AWS_ACCESS_KEY_ID" unless ENV["AWS_ACCESS_KEY_ID"].present?
    missing << "AWS_SECRET_ACCESS_KEY" unless ENV["AWS_SECRET_ACCESS_KEY"].present?

    if missing.any?
      puts "❌ Error: S3 backup configuration missing."
      puts "   Missing: #{missing.join(', ')}"
      puts "   Make sure your .env file exists in: #{Rails.root}"
      exit 1
    end
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new(
      region: region,
      endpoint: endpoint,
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      force_path_style: true
    )
  end

  def region
    ENV["S3_HOSTNAME"].split(".").first
  end

  def endpoint
    "https://#{ENV['S3_HOSTNAME']}"
  end

  def bucket
    ENV["S3_BUCKET"]
  end

  def local_db_path
    Rails.configuration.database_configuration["production"]["database"]
  end

  def list_recent_backups
    puts "📋 Recent backups in #{bucket}:"
    puts

    objects = list_backup_objects.first(10)

    if objects.empty?
      puts "   No backups found."
      return
    end

    objects.each_with_index do |obj, index|
      date = obj.key.sub(".db", "")
      size_mb = (obj.size / 1024.0 / 1024.0).round(2)
      marker = index == 0 ? "👉" : "  "
      puts "#{marker} #{date} (#{size_mb} MB)"
    end

    puts
    puts "To download a specific backup:"
    puts "   bin/rails runner scripts/download_prod_db.rb YYYY-MM-DD"
  end

  def list_backup_objects
    response = s3_client.list_objects_v2(bucket: bucket)
    response.contents
            .select { |obj| obj.key.end_with?(".db") }
            .sort_by(&:last_modified)
            .reverse
  rescue => e
    puts "❌ Error listing backups: #{e.message}"
    exit 1
  end

  def find_backup_key
    if @args.first && @args.first.match?(/^\d{4}-\d{2}-\d{2}$/)
      key = "#{@args.first}.db"
      puts "🔍 Looking for backup: #{key}"

      unless backup_exists?(key)
        puts "❌ Backup not found: #{key}"
        puts
        puts "Recent backups:"
        list_recent_backups
        return nil
      end

      key
    else
      puts "🔍 Finding latest backup..."
      objects = list_backup_objects

      if objects.empty?
        puts "❌ No backups found in bucket: #{bucket}"
        return nil
      end

      latest = objects.first
      puts "   Latest backup: #{latest.key} (#{(latest.size / 1024.0 / 1024.0).round(2)} MB)"
      latest.key
    end
  end

  def backup_exists?(key)
    s3_client.head_object(bucket: bucket, key: key)
    true
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
    false
  end

  def download_backup(key)
    FileUtils.mkdir_p(BACKUP_DIR)
    local_path = BACKUP_DIR.join(key)

    if File.exist?(local_path)
      puts "⚠️  File already exists locally: #{local_path}"
      print "   Overwrite? (y/N): "
      response = STDIN.gets.chomp.downcase
      unless response == "y"
        puts "   Skipping download."
        show_next_steps(local_path)
        return
      end
    end

    puts "⬇️  Downloading #{key}..."

    begin
      s3_client.get_object(bucket: bucket, key: key) do |chunk|
        File.open(local_path, "ab") { |file| file.write(chunk) }
      end

      size_mb = (File.size(local_path) / 1024.0 / 1024.0).round(2)
      puts "✅ Downloaded: #{local_path} (#{size_mb} MB)"

      show_next_steps(local_path)
    rescue => e
      puts "❌ Download failed: #{e.message}"
      File.delete(local_path) if File.exist?(local_path)
      exit 1
    end
  end

  def show_next_steps(local_path)
    puts
    puts "=" * 60
    puts "📝 NEXT STEPS: Replace your database with this backup"
    puts "=" * 60
    puts

    current_db = local_db_path
    backup_name = File.basename(local_path)

    puts "Downloaded: #{local_path}"
    puts "Current DB: #{current_db}"
    puts

    if Rails.env.production?
      puts "⚠️  WARNING: You're in production!"
      puts
      puts "Step 1 - Backup current production DB:"
      puts "   cp #{current_db} #{current_db}.backup.$(date +%Y%m%d%H%M%S)"
      puts
    end

    puts "Step 1 - Stop your Rails server (Ctrl+C)"
    puts

    puts "Step 2 - Replace the database:"
    puts "   cp #{local_path} #{current_db}"
    puts

    if Rails.env.development?
      puts "   # OR use it as your development database:"
      puts "   cp #{local_path} storage/development.sqlite3"
      puts
    end

    puts "Step 3 - Restart your server:"
    puts "   bin/dev"
    puts

    puts "Done! Your database is now replaced with the backup."
    puts "=" * 60
  end
end

# Run the script
DownloadProdDb.new(ARGV).run
