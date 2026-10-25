class AddExpiresAtToApiTokens < ActiveRecord::Migration[7.1]
  def up
    add_column :api_tokens, :expires_at, :datetime

    # すでに発行してあるトークンは、今から90日後を有効期限にする
    execute <<~SQL
      UPDATE api_tokens SET expires_at = #{connection.quote(90.days.from_now)}
    SQL

    change_column_null :api_tokens, :expires_at, false
  end

  def down
    remove_column :api_tokens, :expires_at
  end
end
