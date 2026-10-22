class Account < ApplicationRecord
  belongs_to :user
  encrypts :password

  validates :service_name, presence: true
  validates :password, presence: true

  before_save :check_pwned_password, if: -> { will_save_change_to_password? || pwned_count.nil? }

  # サービス名に、キーワードを含むものだけにしぼる（大文字・小文字は区別しない）
  scope :search, ->(keyword) {
    return all if keyword.blank?

    where("LOWER(service_name) LIKE ?", "%#{sanitize_sql_like(keyword.downcase)}%")
  }

  private

  def check_pwned_password
    self.pwned_count = PwnedPasswordChecker.count(password)
  end
end

