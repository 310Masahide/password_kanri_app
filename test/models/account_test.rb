require "test_helper"

class AccountTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  test "パスワードは暗号化して保存され、読み出すと元に戻る" do
    account = accounts(:alice_amazon)
    assert_not_equal "test1234", account.ciphertext_for(:password)
    assert_equal "test1234", account.password
  end

  test "サービス名が空だと保存できない" do
    account = users(:alice).accounts.build(service_name: "", password: "test1234")
    assert_not account.valid?
  end

  test "パスワードが空だと保存できない" do
    account = users(:alice).accounts.build(service_name: "テスト", password: "")
    assert_not account.valid?
  end

  test "パスワードを変えると、保存中は API を待たずに、裏の流出チェックを予約する" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, ->(_password) { flunk "保存の途中で API を呼んではいけない" }) do
      assert_enqueued_with(job: PwnedCheckJob, args: [ account.id ]) do
        account.update!(password: "password")
      end
    end
    assert_nil account.pwned_count
    assert account.pwned_check_pending?
  end

  test "予約したジョブが動くと、流出回数が記録される" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, 100) do
      perform_enqueued_jobs do
        account.update!(password: "password")
      end
    end
    account.reload
    assert_equal 100, account.pwned_count
    assert_not_nil account.pwned_checked_at
    assert_not account.pwned_check_pending?
  end

  test "ジョブには、パスワードを渡さない" do
    users(:alice).accounts.create!(service_name: "A", password: "secret-password-123")
    assert_equal 1, enqueued_jobs.size
    assert_not_includes enqueued_jobs.first.to_s, "secret-password-123"
  end

  test "パスワードが変わらないときは、流出チェックを予約しない" do
    account = accounts(:alice_amazon)
    assert_no_enqueued_jobs do
      account.update!(memo: "メモだけ変更")
    end
  end

  test "結果をあらかじめ入れて登録したときは、流出チェックを予約しない" do
    assert_no_enqueued_jobs do
      users(:alice).accounts.create!(service_name: "A", password: "password", pwned_count: 3, pwned_checked_at: Time.current)
    end
  end

  test "7日以上前に調べたものだけ、調べ直しを予約する" do
    alice = users(:alice)
    old = accounts(:alice_amazon)
    old.update_columns(pwned_checked_at: 8.days.ago, pwned_check_requested_at: nil)
    alice.accounts.create!(service_name: "最近調べたもの", password: "test1234", pwned_count: 0, pwned_checked_at: 1.day.ago)

    assert_enqueued_jobs 1, only: PwnedCheckJob do
      assert_equal 1, alice.accounts.request_due_pwned_checks!
    end
    assert_enqueued_with(job: PwnedCheckJob, args: [ old.id ])
  end

  test "予約したばかりのものは、続けて一覧を開いても二重に予約しない" do
    alice = users(:alice)
    alice.accounts.update_all(pwned_checked_at: 8.days.ago, pwned_check_requested_at: nil)
    first = alice.accounts.request_due_pwned_checks!
    assert_operator first, :>, 0
    assert_equal 0, alice.accounts.request_due_pwned_checks!
    assert_enqueued_jobs first
  end

  test "予約から1時間たっても結果が出ていなければ、もう一度予約する" do
    account = accounts(:alice_amazon)
    account.update_columns(pwned_count: nil, pwned_checked_at: nil, pwned_check_requested_at: 2.hours.ago)
    assert_not account.reload.pwned_check_pending?
    assert_equal 1, Account.where(id: account.id).request_due_pwned_checks!
  end

  test "ジョブが動く前に削除されていても、エラーにならない" do
    account = accounts(:alice_amazon)
    id = account.id
    account.destroy!
    assert_nothing_raised { PwnedCheckJob.perform_now(id) }
  end

  test "同じパスワードのアカウントがあると、使い回しとして数える" do
    alice = users(:alice)
    first, second = PwnedPasswordChecker.stub(:count, 0) do
      [ alice.accounts.create!(service_name: "A", password: "same-password"),
        alice.accounts.create!(service_name: "B", password: "same-password") ]
    end
    assert_equal 1, first.reused_count
    assert_equal 1, second.reused_count
    assert_includes alice.accounts.reused_fingerprints, first.password_fingerprint
  end

  test "パスワードを変えると、使い回しではなくなる" do
    alice = users(:alice)
    PwnedPasswordChecker.stub(:count, 0) do
      first = alice.accounts.create!(service_name: "A", password: "same-password")
      second = alice.accounts.create!(service_name: "B", password: "same-password")
      second.update!(password: "other-password")
      assert_equal 0, first.reused_count
    end
  end

  test "他人の同じパスワードは使い回しに数えず、指紋も別のものになる" do
    mine, theirs = PwnedPasswordChecker.stub(:count, 0) do
      [ users(:alice).accounts.create!(service_name: "A", password: "same-password"),
        users(:bob).accounts.create!(service_name: "B", password: "same-password") ]
    end
    assert_equal 0, mine.reused_count
    assert_not_equal mine.password_fingerprint, theirs.password_fingerprint
  end

  test "指紋にはパスワードそのものも、ただのハッシュも入らない" do
    account = PwnedPasswordChecker.stub(:count, 0) do
      users(:alice).accounts.create!(service_name: "A", password: "same-password")
    end
    assert_not_includes account.password_fingerprint, "same-password"
    assert_not_equal OpenSSL::Digest::SHA256.hexdigest("same-password"), account.password_fingerprint
  end

  test "再チェックすると、流出回数と確認した日時が更新される" do
    account = accounts(:alice_amazon)
    PwnedPasswordChecker.stub(:count, 5) do
      assert account.recheck_pwned!
    end
    assert_equal 5, account.reload.pwned_count
    assert_not_nil account.pwned_checked_at
  end

  test "再チェックで API が失敗したら、前回の結果を残す" do
    account = accounts(:alice_amazon)
    account.update_columns(pwned_count: 3, pwned_checked_at: 1.day.ago)
    checked_at = account.reload.pwned_checked_at
    PwnedPasswordChecker.stub(:count, nil) do
      assert_not account.recheck_pwned!
    end
    account.reload
    assert_equal 3, account.pwned_count
    assert_equal checked_at, account.pwned_checked_at
  end

  test "長すぎる値は保存できない" do
    account = users(:alice).accounts.build(service_name: "あ" * 101, password: "test1234")
    assert_not account.valid?
    assert_includes account.errors.full_messages, "サービス名は100文字以内で入力してください"

    account = users(:alice).accounts.build(service_name: "テスト", password: "test1234", memo: "あ" * 1001)
    assert_not account.valid?
  end
end
