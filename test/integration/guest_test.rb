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
end
