# Content Security Policy: only this app's own scripts, styles and connections. Importmap's inline script
# carries a per-request nonce. Model output is rendered as filtered Markdown, so this is a second line of defence.
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src(*[ :self, ("ws://localhost:*" if Rails.env.development?) ].compact)
    policy.frame_ancestors :none
    policy.base_uri :self
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_nonce_auto = true
end
