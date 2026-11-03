require "webmock/rspec"

# Specs never reach the network. Stub the Fliip API with WebMock (Client
# specs) or instance_double(FliipApi::Client) (everything above it).
WebMock.disable_net_connect!(allow_localhost: true)
