# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "@popperjs/core", to: "popper.js", preload: true
pin "flatpickr" # @4.6.13
pin "@mapbox/search-js-web", to: "@mapbox--search-js-web.js" # @1.6.0
pin "@floating-ui/core", to: "@floating-ui--core.js" # @0.7.3
pin "@floating-ui/dom", to: "@floating-ui--dom.js" # @0.5.4
pin "@mapbox/search-js-core", to: "@mapbox--search-js-core.js" # @1.6.0
pin "@mapbox/sphericalmercator", to: "@mapbox--sphericalmercator.js" # @1.2.0
pin "focus-trap" # @6.9.4
pin "no-scroll" # @2.1.1
pin "subtag" # @0.5.0
pin "tabbable" # @5.3.3
