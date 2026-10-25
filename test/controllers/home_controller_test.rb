require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "トップページを表示できる" do
    get root_url
    assert_response :success
  end
end
