require "test_helper"

class RegistrationTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "今のパスワードを入れると、ログインパスワードを変えられる" do
    sign_in users(:alice)
    put user_registration_url, params: { user: {
      email: "alice@example.com", password: "new-password-12345",
      password_confirmation: "new-password-12345", current_password: "password123"
    } }
    assert_redirected_to root_url
    assert users(:alice).reload.valid_password?("new-password-12345")
  end

  test "今のパスワードが違うと、変えられない" do
    sign_in users(:alice)
    put user_registration_url, params: { user: {
      email: "alice@example.com", password: "new-password-12345",
      password_confirmation: "new-password-12345", current_password: "wrong-password"
    } }
    assert_response :unprocessable_content
    assert users(:alice).reload.valid_password?("password123")
  end

  test "退会すると、アカウントとトークンも消える" do
    sign_in users(:alice)
    assert_difference(-> { Account.count } => -1, -> { ApiToken.count } => -1) do
      delete user_registration_url
    end
  end
end
