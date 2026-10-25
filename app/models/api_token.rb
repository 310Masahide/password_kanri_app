require "digest"

class ApiToken < ApplicationRecord
  # トークンの有効期限（発行してから90日）
  LIFETIME = 90.days

  belongs_to :user

  validates :name, presence: true, length: { maximum: 50 }
  validates :token_digest, presence: true, uniqueness: true
  validates :expires_at, presence: true

  # 有効期限が切れていないトークンだけ
  scope :active, -> { where("expires_at > ?", Time.current) }

  # トークンを発行する。本物のトークンは、このときにだけ返す
  def self.issue!(user:, name:)
    token = SecureRandom.urlsafe_base64(32)
    api_token = user.api_tokens.create!(name: name, token_digest: digest(token), expires_at: LIFETIME.from_now)
    [api_token, token]
  end

  # 送られてきたトークンから、登録されているトークンを探す
  def self.find_by_token(token)
    return nil if token.blank?

    active.find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  def expired?
    expires_at <= Time.current
  end
end
