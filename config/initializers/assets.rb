# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Sass sources are compiled by dartsass-rails into app/assets/builds, so don't
# publish the raw .scss files as well.
Rails.application.config.assets.excluded_paths << Rails.root.join("app/assets/stylesheets")
