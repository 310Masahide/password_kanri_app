require "application_system_test_case"

class TwoFactorTest < ApplicationSystemTestCase
  test "二段階認証を設定し、次のログインでコードを求められる" do
    alice = users(:alice)
    sign_in alice
    visit two_factor_setting_path
    click_on "設定を始める"

    # QR コードの代わりに表示している文字を読み取り、認証アプリと同じようにコードを作る
    assert_selector "img.qr-code"
    secret = find("code.user-select-all").text.delete(" ")
    fill_in "認証アプリのコード", with: ROTP::TOTP.new(secret).now
    click_on "有効にする"

    assert_text "二段階認証を有効にしました。"
    assert_text "予備コード"
    assert_selector "li.col-6", count: 10

    click_on "ログアウト"
    assert_text "ログアウトしました。"
    visit new_user_session_path
    fill_in "Eメール", with: alice.email
    fill_in "パスワード", with: "password123"
    click_button "ログイン"

    assert_text "認証アプリに表示されている6桁のコード"
    travel 30.seconds do
      fill_in "コード", with: ROTP::TOTP.new(secret).now
      click_on "確認する"
      assert_text "ログインしました。"
    end
  end
end
