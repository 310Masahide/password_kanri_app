# 流出チェックを裏で行うジョブ
# パスワードそのものではなく、アカウントの ID だけを受け取る（予約の情報やログにパスワードを残さないため）
class PwnedCheckJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    # 予約したあとで削除されていたら、何もしない
    account = Account.find_by(id: account_id)
    return if account.nil?

    # 結果が出たら、開いている画面に「読み込み直して」と知らせる
    account.broadcast_pwned_result if account.recheck_pwned!
  end
end
