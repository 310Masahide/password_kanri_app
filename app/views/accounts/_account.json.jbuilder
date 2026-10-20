json.extract! account, :id, :service_name, :login_id, :password, :url, :memo, :user_id, :created_at, :updated_at
json.url account_url(account, format: :json)
