# 流出チェックを裏で行うジョブ
# パスワードそのものではなく、アカウントの ID だけを受け取る（予約の情報やログにパスワードを残さないため）
class PwnedCheckJob < ApplicationJob
  queue_as :default

  def perform(account_id)
    # 予約したあとで削除されていたら、何もしない
    Account.find_by(id: account_id)&.recheck_pwned!
  end
end
