require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "ログインパスワードは12文字以上でないと登録できない" do
    assert_not User.new(email: "short@example.com", password: "a" * 11).valid?
    assert User.new(email: "long@example.com", password: "a" * 12).valid?
  end


  test "二段階認証の秘密の文字列は暗号化して保存し、予備コードはハッシュだけを保存する" do
    alice = users(:alice)
    secret = ROTP::Base32.random
    codes = alice.enable_otp!(secret, ROTP::TOTP.new(secret).now)

    assert_not_includes alice.ciphertext_for(:otp_secret), secret
    assert_equal secret, alice.reload.otp_secret
    assert_equal 10, codes.size
    codes.each { |code| assert_not_includes alice.otp_recovery_digests, code }
  end
end
