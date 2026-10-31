class Account < ApplicationRecord
  belongs_to :user
  encrypts :password

  validates :service_name, presence: true, length: { maximum: 100 }
  validates :login_id, length: { maximum: 255 }
  validates :password, presence: true, length: { maximum: 255 }
  validates :url, length: { maximum: 2048 }
  validates :memo, length: { maximum: 1000 }

  before_save :check_pwned_password, if: :needs_pwned_check?

  # サービス名に、キーワードを含むものだけにしぼる（大文字・小文字は区別しない）
  scope :search, ->(keyword) {
    return all if keyword.blank?

    where("LOWER(service_name) LIKE ?", "%#{sanitize_sql_like(keyword.downcase)}%")
  }

  # 登録した URL のホスト名が、指定したホスト名と一致するか（先頭の「www.」と大文字・小文字の違いは無視する）
  def matches_host?(host)
    return false if host.blank? || url.blank?

    registered_host = URI.parse(url).host
    registered_host.present? && normalize_host(registered_host) == normalize_host(host)
  rescue URI::InvalidURIError
    false
  end

  private

  def normalize_host(host)
    host.downcase.delete_prefix("www.")
  end

  # パスワードが変わったとき、またはまだ調べられていないときに調べる
  # （ゲストのサンプルのように、結果をあらかじめ入れてあるときは調べない）
  def needs_pwned_check?
    pwned_count.nil? || (will_save_change_to_password? && !will_save_change_to_pwned_count?)
  end

  def check_pwned_password
    self.pwned_count = PwnedPasswordChecker.count(password)
  end
end

