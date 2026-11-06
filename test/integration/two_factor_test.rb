require "test_helper"

class TwoFactorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @alice = users(:alice)
    @secret = ROTP::Base32.random
    @recovery_codes = @alice.enable_otp!(@secret, ROTP::TOTP.new(@secret).now)
    # 有効にするときに使ったコードは、もう使えない。テストでは、次の30秒のコードを使う
    @next_code = ROTP::TOTP.new(@secret).at(30.seconds.from_now)
  end

  def log_in(password: "password123")
    post user_session_url, params: { user: { email: @alice.email, password: password } }
  end

  test "二段階認証を使う人は、パスワードが合っても、コードを入れるまでログインできない" do
    log_in
    assert_redirected_to new_users_two_factor_url
    get accounts_url
    assert_redirected_to new_user_session_url
  end

  test "正しいコードを入れると、ログインできる" do
    log_in
    travel 30.seconds do
      post users_two_factor_url, params: { code: @next_code }
    end
    assert_redirected_to root_url
    get accounts_url
    assert_response :success
  end

  test "間違ったコードではログインできず、5回間違えるとロックされる" do
    log_in
    post users_two_factor_url, params: { code: "000000" }
    assert_response :unprocessable_content
    assert_match "コードが正しくありません", response.body

    4.times { post users_two_factor_url, params: { code: "000000" } }
    assert @alice.reload.access_locked?
    assert_redirected_to new_user_session_url
  end

  test "一度使ったコードは、もう一度は使えない" do
    log_in
    travel 30.seconds do
      post users_two_factor_url, params: { code: @next_code }
      delete destroy_user_session_url
      log_in
      post users_two_factor_url, params: { code: @next_code }
    end
    assert_response :unprocessable_content
  end

  test "予備コードでもログインでき、同じ予備コードは2回使えない" do
    log_in
    post users_two_factor_url, params: { code: @recovery_codes.first }
    assert_redirected_to root_url
    assert_equal 9, @alice.reload.otp_recovery_digests.size

    delete destroy_user_session_url
    log_in
    post users_two_factor_url, params: { code: @recovery_codes.first }
    assert_response :unprocessable_content
  end

  test "パスワードを確かめてから5分たつと、最初からやり直しになる" do
    log_in
    travel 6.minutes do
      post users_two_factor_url, params: { code: ROTP::TOTP.new(@secret).now }
    end
    assert_redirected_to new_user_session_url
  end

  test "パスワードが違うときは、コードの画面に進まない" do
    log_in(password: "wrong-password")
    assert_response :unprocessable_content
    assert_match "Eメールまたはパスワードが違います", response.body
  end

  test "パスワードを確かめていないと、コードの画面は開けない" do
    get new_users_two_factor_url
    assert_redirected_to new_user_session_url
  end

  test "二段階認証を使っていない人は、いつもどおりログインできる" do
    @alice.disable_otp!
    log_in
    assert_redirected_to root_url
  end
end
