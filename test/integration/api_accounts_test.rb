require "test_helper"

class ApiAccountsTest < ActionDispatch::IntegrationTest
  setup do
    @headers = { "Authorization" => "Bearer alice-secret-token" }
  end

  test "トークンがないと、401（認証エラー）を返す" do
    get api_v1_accounts_url, params: { host: "example.com" }
    assert_response :unauthorized
  end

  test "間違ったトークンだと、401（認証エラー）を返す" do
    get api_v1_accounts_url, params: { host: "example.com" }, headers: { "Authorization" => "Bearer wrong-token" }
    assert_response :unauthorized
  end

  test "ホスト名が一致する、自分のアカウントだけを返す" do
    get api_v1_accounts_url, params: { host: "www.example.com" }, headers: @headers
    assert_response :success
    json = response.parsed_body
    assert_equal ["アリスのショッピング"], json.map { |account| account["service_name"] }
    assert_equal "test1234", json.first["password"]
  end

  test "ホスト名が少しでも違うと、何も返さない（偽サイト対策）" do
    %w[examp1e.com example.com.evil.com login.example.com].each do |host|
      get api_v1_accounts_url, params: { host: host }, headers: @headers
      assert_equal [], response.parsed_body, "#{host} で返してはいけない"
    end
  end

  test "使うと、トークンの「最後に使った日時」が記録される" do
    assert_nil api_tokens(:alice_chrome).last_used_at
    get api_v1_accounts_url, params: { host: "example.com" }, headers: @headers
    assert_not_nil api_tokens(:alice_chrome).reload.last_used_at
  end
end
