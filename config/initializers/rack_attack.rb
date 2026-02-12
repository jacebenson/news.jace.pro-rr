# config/initializers/rack_attack.rb
# Rate limiting and request throttling for security
# https://github.com/rack/rack-attack

class Rack::Attack
  ### Configure Cache ###
  # Use Rails cache (Solid Cache in production)
  Rack::Attack.cache.store = Rails.cache

  ### Throttle Spammy Clients ###
  # If any single client IP is making tons of requests, block them
  # 1000 requests per minute is reasonable - allows fast browsing but blocks abuse
  throttle("req/ip", limit: 1000, period: 1.minute) do |req|
    req.ip unless req.path.start_with?("/assets")
  end

  ### Prevent Brute-Force Login Attacks ###
  # Throttle login attempts by IP address
  throttle("logins/ip", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      req.ip
    end
  end

  # Throttle login attempts by email parameter
  throttle("logins/email", limit: 5, period: 20.seconds) do |req|
    if req.path == "/login" && req.post?
      # Normalize email to prevent bypassing throttle
      req.params["email"].to_s.downcase.gsub(/\s/, "").presence
    end
  end

  ### Prevent Password Reset Spam ###
  throttle("password_reset/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/password" && req.post?
      req.ip
    end
  end

  ### Prevent User Registration Spam ###
  throttle("signup/ip", limit: 5, period: 1.hour) do |req|
    if req.path == "/signup" && req.post?
      req.ip
    end
  end

  ### Block Bad User Agents ###
  blocklist("block bad UA") do |req|
    # Block requests with no user agent (bots)
    # Be careful - some legitimate tools may not send UA
    # req.user_agent.blank?
    false  # Disabled by default - uncomment above if needed
  end

  ### Custom Blocklist Response ###
  self.blocklisted_responder = lambda do |req|
    [ 503, { "Content-Type" => "text/plain" }, [ "Service Unavailable\n" ] ]
  end

  ### Custom Throttle Response ###
  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s },
      [ "Rate limit exceeded. Try again in #{retry_after} seconds.\n" ]
    ]
  end
end

# Log blocked/throttled requests in development
if Rails.env.development?
  ActiveSupport::Notifications.subscribe("throttle.rack_attack") do |_name, _start, _finish, _request_id, payload|
    Rails.logger.warn "[Rack::Attack] Throttled #{payload[:request].ip}"
  end
end
