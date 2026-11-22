# Two stylesheets while the front end is rebuilt: the old Bootstrap one and
# the new layout's (layouts/studio). ENG-216 goes back to one build.
Rails.application.config.dartsass.builds = {
  "application.scss" => "application.css",
  "studio.scss" => "studio.css"
}

# Bootstrap 5.3 still uses the deprecated Sass @import; hide warnings that come
# from dependencies so only our own stylesheets report problems.
Rails.application.config.dartsass.build_options << "--quiet-deps"
