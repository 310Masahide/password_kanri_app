require "test_helper"
# 画面への知らせ（Turbo Streams）を確かめるための道具を読み込む
require "turbo/broadcastable/test_helper"

class PwnedCheckJobTest < ActiveJob::TestCase
  include Turbo::Broadcastable::TestHelper

  setup do
    @account = accounts(:alice_amazon)
  end

  test "結果が出たら、詳細画面と一覧に「読み込み直して」と知らせる" do
    PwnedPasswordChecker.stub(:count, 3) do
      assert_turbo_stream_broadcasts @account do
        assert_turbo_stream_broadcasts [ @account.user, :accounts ] do
          PwnedCheckJob.perform_now(@account.id)
        end
      end
    end
  end

  test "知らせには、パスワードも結果も入れない" do
    broadcasts = PwnedPasswordChecker.stub(:count, 3) do
      capture_turbo_stream_broadcasts(@account) { PwnedCheckJob.perform_now(@account.id) }
    end
    assert_equal [ "refresh" ], broadcasts.map { |b| b["action"] }
    assert_not_includes broadcasts.to_s, "test1234"
  end

  test "調べられなかったときは、知らせない" do
    PwnedPasswordChecker.stub(:count, nil) do
      assert_no_turbo_stream_broadcasts @account do
        PwnedCheckJob.perform_now(@account.id)
      end
    end
  end
end
