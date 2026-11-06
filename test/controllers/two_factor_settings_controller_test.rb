require "test_helper"

class TwoFactorSettingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @alice = users(:alice)
    sign_in @alice
  end

  test "正しいコードを入れると有効になり、予備コードが1回だけ表示される" do
    get new_two_factor_setting_url
    assert_select "img.qr-code"
    secret = session[:otp_setup_secret]

    post two_factor_setting_url, params: { code: ROTP::TOTP.new(secret).now }
    assert_redirected_to two_factor_setting_url
    assert @alice.reload.otp_enabled?

    follow_redirect!
    assert_select "li.col-6", count: 10
    get two_factor_setting_url
    assert_select "li.col-6", count: 0
  end

  test "間違ったコードでは、有効にならない" do
    get new_two_factor_setting_url
    post two_factor_setting_url, params: { code: "000000" }
    assert_response :unprocessable_content
    assert_not @alice.reload.otp_enabled?
  end

  test "やめるときは、正しいパスワードが必要" do
    secret = ROTP::Base32.random
    @alice.enable_otp!(secret, ROTP::TOTP.new(secret).now)

    delete two_factor_setting_url, params: { current_password: "wrong-password" }
    assert @alice.reload.otp_enabled?

    delete two_factor_setting_url, params: { current_password: "password123" }
    assert_not @alice.reload.otp_enabled?
  end

  test "ゲストは二段階認証を設定できない" do
    sign_in User.guest
    get new_two_factor_setting_url
    assert_redirected_to accounts_url
  end
end
