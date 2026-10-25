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


  test "アカウントを登録できる（持ち主はトークンの持ち主になり、送られてきた user_id は無視される）" do
    PwnedPasswordChecker.stub(:count, 0) do
      assert_difference("users(:alice).accounts.count", 1) do
        post api_v1_accounts_url, headers: @headers, as: :json, params: {
          account: { service_name: "新しいサイト", login_id: "alice_new", password: "abc12345",
                     url: "https://new.example.com/login", user_id: users(:bob).id }
        }
      end
    end
    assert_response :created
    assert_equal "新しいサイト", response.parsed_body["service_name"]
    assert_equal users(:alice), Account.find(response.parsed_body["id"]).user
  end

  test "サービス名が空だと登録せず、422 とエラーの内容を返す" do
    assert_no_difference("Account.count") do
      post api_v1_accounts_url, headers: @headers, as: :json,
                                params: { account: { service_name: "", password: "abc12345" } }
    end
    assert_response :unprocessable_content
    assert_includes response.parsed_body["errors"], "サービス名を入力してください"
  end

  test "トークンがないと登録できない" do
    assert_no_difference("Account.count") do
      post api_v1_accounts_url, as: :json, params: { account: { service_name: "新しいサイト", password: "abc12345" } }
    end
    assert_response :unauthorized
  end

  test "API の返事も、ブラウザに保存させない（Cache-Control: no-store）" do
    get api_v1_accounts_url, params: { host: "example.com" }, headers: @headers
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "有効期限が切れたトークンは使えない" do
    travel 91.days do
      get api_v1_accounts_url, params: { host: "example.com" }, headers: @headers
      assert_response :unauthorized
    end
  end
end
