require "net/http"
require "digest"

class PwnedPasswordChecker
  API_URL = "https://api.pwnedpasswords.com/range/"

  # 流出回数を返す（0 なら流出なし、nil なら確認できなかった）
  def self.count(password)
    sha1 = Digest::SHA1.hexdigest(password).upcase
    prefix = sha1[0, 5]
    suffix = sha1[5..]

    uri = URI(API_URL + prefix)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 3) do |http|
      http.get(uri.request_uri)
    end
    return nil unless response.is_a?(Net::HTTPSuccess)

    response.body.each_line do |line|
      hash_suffix, count = line.strip.split(":")
      return count.to_i if hash_suffix == suffix
    end
    0
  rescue StandardError
    nil
  end
end
