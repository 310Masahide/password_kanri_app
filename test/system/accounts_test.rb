require "application_system_test_case"

class AccountsTest < ApplicationSystemTestCase
  setup do
    @alice = users(:alice)
    @account = accounts(:alice_amazon)
  end

  test "ゲストログインすると、サンプルの入った一覧が開く" do
    visit root_path
    click_on "ゲストログイン（登録なしで試す）"
    assert_text "アカウント一覧"
    assert_text "サンプル：ショッピングサイト"
    assert_link "流出あり 1件"
  end

  test "詳細画面で、パスワードの表示と非表示を切り替えられる" do
    sign_in @alice
    visit account_path(@account)
    assert_no_text "test1234"

    click_on "表示"
    assert_text "test1234"
    assert_button "隠す"

    click_on "隠す"
    assert_no_text "test1234"
  end

  test "自動作成を押すと、16文字のパスワードが入り、押すたびに変わる" do
    sign_in @alice
    visit new_account_path

    click_on "自動作成"
    first = find_field("パスワード").value
    assert_equal 16, first.length
    assert_equal "text", find_field("パスワード")[:type]

    click_on "自動作成"
    assert_not_equal first, find_field("パスワード").value
  end

  test "コピーを押すと、パスワードがクリップボードに入る" do
    sign_in @alice
    visit account_path(@account)
    allow_clipboard

    within(:xpath, "//dt[text()='パスワード']/following-sibling::dd[1]") do
      click_on "コピー"
      assert_button "コピーしました（30秒で消えます）"
    end
    assert_equal "test1234", clipboard_text
  end

  test "裏の流出チェックが終わると、読み込み直さなくても結果が表示される" do
    sign_in @alice
    @account.update_columns(pwned_count: nil, pwned_checked_at: nil, pwned_check_requested_at: Time.current)
    visit account_path(@account)
    assert_selector ".badge", text: "確認中"
    # 画面が知らせを受け取る準備ができるまで待つ
    assert_selector "turbo-cable-stream-source[connected]", visible: :all

    PwnedPasswordChecker.stub(:count, 3) do
      PwnedCheckJob.perform_now(@account.id)
    end

    assert_selector ".badge", text: "流出あり"
    assert_text "過去に3回流出しています"
  end

  test "削除は、確認でOKを押したときだけ行う" do
    sign_in @alice
    visit account_path(@account)

    dismiss_confirm("本当に削除しますか？") { click_on "削除" }
    assert_text @account.service_name
    assert Account.exists?(@account.id)

    accept_confirm("本当に削除しますか？") { click_on "削除" }
    assert_text "削除しました。"
    assert_not Account.exists?(@account.id)
  end
end
