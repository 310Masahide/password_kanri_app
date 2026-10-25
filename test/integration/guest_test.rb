require "test_helper"

class GuestTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "ゲストログインすると、サンプルデータが2件入った状態で一覧に移動する" do
    PwnedPasswordChecker.stub(:count, 0) do
      post users_guest_sign_in_url
    end
    assert_redirected_to accounts_url
    assert_equal 2, User.guest.accounts.count
  end

  test "ゲストは登録情報を変更できない" do
    guest = User.guest
    sign_in guest
    patch user_registration_url, params: { user: { email: "new@example.com" } }
    assert_redirected_to root_url
    assert_equal User::GUEST_EMAIL, guest.reload.email
  end

  test "ゲストは退会できない" do
    sign_in User.guest
    assert_no_difference("User.count") do
      delete user_registration_url
    end
    assert_redirected_to root_url
  end

  test "ゲストは、拡張機能のトークンを発行できない" do
    sign_in User.guest
    assert_no_difference("ApiToken.count") do
      post api_tokens_url, params: { name: "ゲストのChrome" }
    end
    assert_redirected_to accounts_url
  end

  test "ゲストログインすると、前の人が発行したトークンは消える" do
    guest = User.guest
    ApiToken.issue!(user: guest, name: "前の人のChrome")
    PwnedPasswordChecker.stub(:count, 0) do
      post users_guest_sign_in_url
    end
    assert_equal 0, guest.api_tokens.count
  end

  test "誰かがゲストのメールアドレスでログインに失敗し続けても、ゲストログインは使える" do
    User.guest
    5.times do
      post user_session_url, params: { user: { email: User::GUEST_EMAIL, password: "wrong-password" } }
    end
    assert User.guest.access_locked?

    PwnedPasswordChecker.stub(:count, 0) do
      post users_guest_sign_in_url
    end
    assert_redirected_to accounts_url
    get accounts_url
    assert_response :success
  end
end
