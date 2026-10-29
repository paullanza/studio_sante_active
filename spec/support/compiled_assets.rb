# The stylesheet is compiled by dartsass-rails into app/assets/builds, which is
# not committed. Build it once if it is missing so views that link it can render.
RSpec.configure do |config|
  config.before(:suite) do
    next if Rails.root.join("app/assets/builds/application.css").exist?

    system("bin/rails dartsass:build", exception: true)
  end
end
