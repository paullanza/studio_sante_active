require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module StudioSanteActive
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # 7.2 enables YJIT by default; it adds memory overhead and Render's free plan
    # has 512 MB. Revisit when the instance size is known.
    config.yjit = false

    # Active Storage isn't used; don't warn about the missing image_processing gem.
    config.active_storage.variant_processor = :disabled

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = 'Eastern Time (US & Canada)'

    # Generators: RSpec with FactoryBot, request specs only (no fixtures,
    # view, routing, helper or controller specs), and no empty helper modules.
    config.generators do |g|
      g.helper false
      g.test_framework :rspec,
                       fixtures: false,
                       view_specs: false,
                       routing_specs: false,
                       helper_specs: false,
                       controller_specs: false,
                       request_specs: true
      g.fixture_replacement :factory_bot, dir: "spec/factories"
    end
    # config.eager_load_paths << Rails.root.join("extras")

    config.active_job.queue_adapter = :solid_queue

    # Mission Control (/jobs) runs behind our own login and admin policy
    # instead of HTTP Basic auth.
    config.mission_control.jobs.base_controller_class = "MissionControlBaseController"
    config.mission_control.jobs.http_basic_auth_enabled = false
    # Always Solid Queue, even in specs where Active Job uses the test adapter.
    config.mission_control.jobs.adapters = [ :solid_queue ]
  end
end
