# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

# Rails.application.configure do
#   config.content_security_policy do |policy|
#     policy.default_src :self, :https
#     policy.font_src    :self, :https, :data
#     policy.img_src     :self, :https, :data
#     policy.object_src  :none
#     policy.script_src  :self, :https

#     if Rails.env.local?
#       policy.connect_src :self, :https, "http://#{ViteRuby.config.host_with_port}", "ws://#{ViteRuby.config.host_with_port}"
#       policy.script_src  :self, :https, :unsafe_eval, "http://#{ViteRuby.config.host_with_port}"
#       policy.style_src   :self, :https, :unsafe_inline
#       policy.script_src  :self, :https, :unsafe_eval, :blob
#     end
#   end

#   config.content_security_policy_report_only = true
# end
