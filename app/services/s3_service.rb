require "aws-sdk-s3"

class S3Service
  class << self
    def client
      @client ||= Aws::S3::Client.new(
        region: region,
        endpoint: endpoint,
        access_key_id: ENV["AWS_ACCESS_KEY_ID"],
        secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
        force_path_style: true  # Required for S3-compatible services like Hetzner
      )
    end

    def enabled?
      ENV["S3_HOSTNAME"].present? &&
        ENV["AWS_ACCESS_KEY_ID"].present? &&
        ENV["AWS_SECRET_ACCESS_KEY"].present? &&
        ENV["S3_ASSET_BUCKET"].present?
    end

    def endpoint
      "https://#{ENV['S3_HOSTNAME']}"
    end

    def region
      # Extract region from hostname (e.g., "hel1" from "hel1.your-objectstorage.com")
      ENV["S3_HOSTNAME"]&.split(".")&.first || "us-east-1"
    end

    def asset_bucket
      ENV["S3_ASSET_BUCKET"]
    end

    def backup_bucket
      ENV["S3_BUCKET"]
    end

    # Check if a file exists in the asset bucket
    def file_exists?(key)
      return false unless enabled?

      client.head_object(bucket: asset_bucket, key: key)
      true
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey
      false
    rescue => e
      Rails.logger.error "[S3] Error checking file existence: #{e.message}"
      false
    end

    # Upload a file to the asset bucket
    # @param key [String] The S3 key (path) for the file
    # @param body [String, IO] The file content or IO object
    # @param content_type [String] The MIME type (optional)
    # @return [String, nil] The public URL or nil on failure
    def upload_asset(key:, body:, content_type: nil)
      return nil unless enabled?

      # Skip if file already exists
      if file_exists?(key)
        Rails.logger.debug "[S3] File already exists: #{key}"
        return public_url(key)
      end

      params = {
        bucket: asset_bucket,
        key: key,
        body: body,
        acl: "public-read"
      }
      params[:content_type] = content_type if content_type

      client.put_object(params)
      Rails.logger.info "[S3] Uploaded: #{key}"
      public_url(key)
    rescue => e
      Rails.logger.error "[S3] Upload failed for #{key}: #{e.message}"
      nil
    end

    # Upload a file from a local path
    def upload_file(key:, file_path:, content_type: nil)
      return nil unless File.exist?(file_path)

      body = File.open(file_path, "rb")
      content_type ||= detect_content_type(file_path)
      upload_asset(key: key, body: body, content_type: content_type)
    ensure
      body&.close
    end

    # Download an image from URL and upload to S3
    # @param url [String] The image URL to download
    # @param key [String] The S3 key to store it as
    # @return [String, nil] The public URL or nil on failure
    def upload_from_url(url:, key:)
      return nil unless enabled?
      return public_url(key) if file_exists?(key)

      # Download the image
      response = HTTParty.get(url, timeout: 30, headers: {
        "User-Agent" => "Mozilla/5.0 (compatible; NewsBot/1.0)"
      })

      return nil unless response.success?

      content_type = response.headers["content-type"]
      upload_asset(key: key, body: response.body, content_type: content_type)
    rescue => e
      Rails.logger.error "[S3] Failed to upload from URL #{url}: #{e.message}"
      nil
    end

    # Get the public URL for an asset
    def public_url(key)
      "#{endpoint}/#{asset_bucket}/#{key}"
    end

    # Upload database backup to the backup bucket
    def upload_backup(file_path:, key:)
      return nil unless enabled?
      return nil unless ENV["S3_BUCKET"].present?

      body = File.open(file_path, "rb")
      client.put_object(
        bucket: backup_bucket,
        key: key,
        body: body
      )
      Rails.logger.info "[S3] Backup uploaded: #{key}"
      true
    rescue => e
      Rails.logger.error "[S3] Backup upload failed: #{e.message}"
      false
    ensure
      body&.close
    end

    private

    def detect_content_type(file_path)
      ext = File.extname(file_path).downcase
      {
        ".jpg" => "image/jpeg",
        ".jpeg" => "image/jpeg",
        ".png" => "image/png",
        ".gif" => "image/gif",
        ".webp" => "image/webp",
        ".svg" => "image/svg+xml"
      }[ext] || "application/octet-stream"
    end
  end
end
