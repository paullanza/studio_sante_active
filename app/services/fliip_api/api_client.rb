module FliipApi
  class ApiClient
    include HTTParty

    base_uri 'https://static.fliipapp.com/api/v2'

    def initialize
      @headers = { 'Authorization' => ENV.fetch('FLIIP_API_KEY') }
    end

    def fetch_users(limit = 10_000)
      response = self.class.get("/users/get?limit=#{limit}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!).reverse!
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end
  end
end
