module FliipApi
  # ApiClient encapsulates all HTTP calls to the Fliip REST API
  # Uses HTTParty for simplicity; each method logs errors and returns structured data or an empty array
  class ApiClient
    include HTTParty

    # Base URI for all requests to the v2 API
    base_uri 'https://static.fliipapp.com/api/v2'

    def initialize
      # API key is pulled from environment; ensure ENV['FLIIP_API_KEY'] is set
      @headers = { 'Authorization' => ENV.fetch('FLIIP_API_KEY') }
    end

    # Fetches up to `limit` users in a single call, symbolizing keys and reversing order
    # as the data comes back newest first.
    # @param limit [Integer] maximum number of users to retrieve
    # @return [Array<Hash>] array of user hashes, or [] on failure
    def fetch_all_users(limit = 10_000)
      response = self.class.get("/users/get?limit=#{limit}", headers: @headers)

      if response.success?
        # Convert keys to symbols and reverse array so oldest records first
        response.parsed_response.map(&:deep_symbolize_keys!).reverse!
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches detailed data for a single user by ID
    # @param user_id [String, Integer] remote identifier
    # @return [Hash] user details or {} on failure
    def fetch_single_user(user_id)
      response = self.class.get("/users/details/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.deep_symbolize_keys!
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches contract data for a given user
    # @param user_id [String, Integer] remote identifier
    # @return [Array<Hash>] contract records or [] on failure
    def fetch_user_contracts(user_id)
      response = self.class.get("/contracts/get/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end
  end
end
