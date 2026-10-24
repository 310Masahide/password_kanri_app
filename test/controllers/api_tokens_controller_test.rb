require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "ログインしていないと、トークンの画面を見られない" do
    get api_tokens_url
    assert_redirected_to new_user_session_url
  end

  test "トークンを発行すると、本物のトークンは画面に1回だけ表示され、データベースにはハッシュだけが保存される" do
    sign_in users(:alice)
    assert_difference("users(:alice).api_tokens.count", 1) do
      post api_tokens_url, params: { name: "テスト用" }
    end
    assert_response :success
    token = css_select("input.font-monospace").first["value"]
    assert_equal 43, token.length
    assert_equal ApiToken.digest(token), ApiToken.last.token_digest
    assert_not_equal token, ApiToken.last.token_digest
    assert_equal ApiToken.last, ApiToken.find_by_token(token)

    get api_tokens_url
    assert_no_match token, response.body
  end

  test "他人のトークンは削除できない" do
    sign_in users(:bob)
    assert_no_difference("ApiToken.count") do
      delete api_token_url(api_tokens(:alice_chrome))
    end
    assert_response :not_found
  end
end
