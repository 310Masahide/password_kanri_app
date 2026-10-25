require "test_helper"

class LoginSecurityTest < ActionDispatch::IntegrationTest
  test "ログインに5回失敗すると、正しいパスワードでもしばらくログインできない" do
    5.times do
      post user_session_url, params: { user: { email: "alice@example.com", password: "wrong-password" } }
    end
    assert users(:alice).reload.access_locked?

    post user_session_url, params: { user: { email: "alice@example.com", password: "password123" } }
    get accounts_url
    assert_redirected_to new_user_session_url
  end

  test "ロックは15分たつと、自動で解除される" do
    5.times do
      post user_session_url, params: { user: { email: "alice@example.com", password: "wrong-password" } }
    end

    travel 16.minutes do
      post user_session_url, params: { user: { email: "alice@example.com", password: "password123" } }
      get accounts_url
      assert_response :success
    end
  end

  test "30分なにも操作しないと、自動でログアウトする" do
    post user_session_url, params: { user: { email: "alice@example.com", password: "password123" } }
    get accounts_url
    assert_response :success

    travel 31.minutes do
      get accounts_url
      # Devise は、いったん同じページに戻してから、ログイン画面に移動させる
      follow_redirect!
      assert_redirected_to new_user_session_url
    end
  end
end
