# Bootstrap 5.3 still uses the deprecated Sass @import; hide warnings that come
# from dependencies so only our own stylesheets report problems.
Rails.application.config.dartsass.build_options << "--quiet-deps"
