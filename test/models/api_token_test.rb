require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "発行したトークンは、90日後に有効期限が切れる" do
    api_token, token = ApiToken.issue!(user: users(:alice), name: "テスト用")
    assert_in_delta 90.days.from_now, api_token.expires_at, 1.minute
    assert_equal api_token, ApiToken.find_by_token(token)

    travel 91.days do
      assert api_token.expired?
      assert_nil ApiToken.find_by_token(token)
    end
  end
end
