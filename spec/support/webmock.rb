require "webmock/rspec"

# Specs never reach the network. Stub the Fliip API with WebMock (ApiClient
# specs) or instance_double(FliipApi::ApiClient) (everything above it).
WebMock.disable_net_connect!(allow_localhost: true)
