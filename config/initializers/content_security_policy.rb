# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data
    policy.object_src  :none
    # Allow inline scripts - needed for Turbo compatibility and Chart.js
    # The site doesn't handle sensitive user data, so this is acceptable
    policy.script_src  :self, :https, :unsafe_inline, "cdn.jsdelivr.net"
    policy.style_src   :self, :https, :unsafe_inline  # Tailwind requires unsafe-inline
    policy.connect_src :self, :https
    policy.frame_src   :self, "youtube.com", "www.youtube.com", "anchor.fm",
                       "podcasters.spotify.com", "share.transistor.fm", "omny.fm"
  end

  # Nonces disabled - they conflict with Turbo's page caching/navigation
  # config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  # config.content_security_policy_nonce_directives = %w[script-src]

  # Report violations without enforcing the policy (useful for testing)
  # config.content_security_policy_report_only = true
end
