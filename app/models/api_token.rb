require "digest"

class ApiToken < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :token_digest, presence: true, uniqueness: true

  # トークンを発行する。本物のトークンは、このときにだけ返す
  def self.issue!(user:, name:)
    token = SecureRandom.urlsafe_base64(32)
    api_token = user.api_tokens.create!(name: name, token_digest: digest(token))
    [api_token, token]
  end

  # 送られてきたトークンから、登録されているトークンを探す
  def self.find_by_token(token)
    return nil if token.blank?

    find_by(token_digest: digest(token))
  end

  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end
end
