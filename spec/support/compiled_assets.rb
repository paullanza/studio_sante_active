# The stylesheets are compiled by dartsass-rails into app/assets/builds, which
# is not committed. Build them once if any is missing so views that link them
# can render.
RSpec.configure do |config|
  config.before(:suite) do
    builds = %w[application.css studio.css].map { |name| Rails.root.join("app/assets/builds", name) }
    next if builds.all?(&:exist?)

    system("bin/rails dartsass:build", exception: true)
  end
end
