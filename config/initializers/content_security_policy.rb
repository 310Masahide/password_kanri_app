# Be sure to restart your server when you modify this file.

# ブラウザに「このアプリが読み込んでよいもの」を伝える（XSS が入り込んだときの、もう一段の守り）
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.script_src  :self
    # Bootstrap は CDN から読み込む
    policy.style_src   :self, "https://cdn.jsdelivr.net"
    # Bootstrap の CSS は、チェックボックスなどの小さな画像を data: で使う
    policy.img_src     :self, :data
    policy.object_src  :none
    policy.base_uri    :self
    policy.form_action :self
    policy.frame_ancestors :none
  end

  # importmap と Turbo が書き出す <script> と <style> に、合言葉（nonce）を付けて許可する
  # セッション ID を合言葉にすると、初めて来た人（セッションがまだない）のときに空になるので、毎回ランダムに作る
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
end
