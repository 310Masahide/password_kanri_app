require "test_helper"

class AccountsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @alice = users(:alice)
    @alice_account = accounts(:alice_amazon)
    @bob_account = accounts(:bob_sns)
  end

  test "ログインしていないと、一覧を見られずログイン画面に移動する" do
    get accounts_url
    assert_redirected_to new_user_session_url
  end

  test "一覧には自分のデータだけが表示される" do
    sign_in @alice
    get accounts_url
    assert_response :success
    assert_match @alice_account.service_name, response.body
    assert_no_match @bob_account.service_name, response.body
  end

  test "登録画面のパスワード欄は、ブラウザに保存済みのパスワードを自動で入れさせない" do
    sign_in @alice
    get new_account_url
    assert_select "input[type=password][autocomplete=new-password]"
    assert_select ".alert-warning", count: 0
  end

  test "画面には、読み込んでよいものを決める CSP のヘッダーが付く" do
    sign_in @alice
    get account_url(@alice_account)
    csp = response.headers["Content-Security-Policy"]
    assert_match "script-src 'self'", csp
    assert_match "frame-ancestors 'none'", csp
  end

  test "初めて来た人の画面でも、JavaScript を読み込むための合言葉（nonce）が空にならない" do
    get new_user_session_url
    nonce = css_select("script[type=importmap]").first["nonce"]
    assert nonce.present?
    assert_match "'nonce-#{nonce}'", response.headers["Content-Security-Policy"]
  end

  test "同じパスワードのアカウントは、一覧にバッジ、詳細に注意が出る" do
    sign_in @alice
    get accounts_url
    assert_select ".badge", text: "使い回し", count: 0

    account = PwnedPasswordChecker.stub(:count, 0) do
      @alice.accounts.create!(service_name: "同じパスワード1", password: "same-password")
      @alice.accounts.create!(service_name: "同じパスワード2", password: "same-password")
    end
    get accounts_url
    assert_select ".badge", text: "使い回し", count: 2
    get account_url(account)
    assert_select ".alert-warning", text: /ほかの1件のアカウントと同じパスワードです/
  end

  test "再チェックのボタンで、流出チェックをやり直せる" do
    sign_in @alice
    PwnedPasswordChecker.stub(:count, 7) do
      post recheck_account_url(@alice_account)
    end
    assert_redirected_to account_url(@alice_account)
    assert_equal 7, @alice_account.reload.pwned_count
  end

  test "再チェックができなかったときは、そのことを伝える" do
    sign_in @alice
    PwnedPasswordChecker.stub(:count, nil) do
      post recheck_account_url(@alice_account)
    end
    follow_redirect!
    assert_select ".alert-danger", text: /前回の結果のままです/
    assert_equal 0, @alice_account.reload.pwned_count
  end

  test "他人のデータは再チェックできない" do
    sign_in @alice
    post recheck_account_url(@bob_account)
    assert_response :not_found
  end

  test "他人のデータの詳細は見られない" do
    sign_in @alice
    get account_url(@bob_account)
    assert_response :not_found
  end

  test "他人のデータは更新できない" do
    sign_in @alice
    patch account_url(@bob_account), params: { account: { service_name: "書き換え" } }
    assert_response :not_found
    assert_equal "ボブのSNS", @bob_account.reload.service_name
  end

  test "他人のデータは削除できない" do
    sign_in @alice
    assert_no_difference("Account.count") do
      delete account_url(@bob_account)
    end
    assert_response :not_found
  end

  test "登録したデータは自分のものになる（他人のuser_idを送っても無視される）" do
    sign_in @alice
    PwnedPasswordChecker.stub(:count, 0) do
      assert_difference("@alice.accounts.count", 1) do
        post accounts_url, params: { account: { service_name: "新しいサービス", password: "test1234", user_id: users(:bob).id } }
      end
    end
    assert_redirected_to account_url(@alice.accounts.last)
  end

  test "詳細画面に、ログインID・コピーボタン・ログインページを開くボタンが表示される" do
    sign_in @alice
    get account_url(@alice_account)
    assert_response :success
    assert_match @alice_account.login_id, response.body
    assert_select "button[data-action='clipboard#copy']", 2
    assert_select "a[data-action='clipboard#copy'][href='#{@alice_account.url}']", text: /ログインページを開く/
  end

  test "URLが http(s):// で始まらないときは、リンクにしない" do
    @alice_account.update_columns(url: "javascript:alert(1)")
    sign_in @alice
    get account_url(@alice_account)
    assert_response :success
    assert_select "a[href^='javascript']", 0
  end

  test "パスワードが映る画面は、ブラウザに保存させない（Cache-Control: no-store）" do
    sign_in @alice
    get account_url(@alice_account)
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "JSON の形では、アカウントを取り出せない" do
    sign_in @alice
    get accounts_url(format: :json)
    assert_response :not_acceptable
    assert_not_equal "application/json", response.media_type
  end
end
