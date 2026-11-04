require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module PasswordKanriApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.time_zone = "Tokyo"
    config.i18n.default_locale = :ja

    # 画像を扱わないので、Active Storage の画像変換は使わない
    config.active_storage.variant_processor = :disabled

    # ジョブは、Web サーバーと同じプロセスの中で動かす（無料の Render では、ジョブ専用のサーバーを用意できないため）
    # サーバーが再起動すると予約したジョブは消えるが、一覧を開いたときに予約し直すので、チェックが漏れたままにはならない
    config.active_job.queue_adapter = :async

    # config.eager_load_paths << Rails.root.join("extras")
  end
end
