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
    def fetch_all_users(limit = 100)
      all_users = []
      offset = 0

      loop do
        response = self.class.get("/users/get?limit=#{limit}&offset=#{offset}", headers: @headers)
        break unless response.success?

        batch = response.parsed_response.map(&:deep_symbolize_keys!)
        break if batch.empty?

        all_users.concat(batch)
        break if batch.size < limit
        offset += limit
      end

      all_users.reverse
    end

    # Fetches detailed data for a single user by ID
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
    def fetch_user_contracts(user_id)
      response = self.class.get("/contracts/get/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches contract data for a given user
    def fetch_future_user_contracts(user_id)
      response = self.class.get("/contracts/get_future/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches contract data for a given user
    def fetch_history_user_contracts(user_id)
      response = self.class.get("/contracts/get_history/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches service data for a given user
    def fetch_user_services(user_id)
      response = self.class.get("/services/get/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches service data for a given user
    def fetch_future_user_services(user_id)
      response = self.class.get("/services/get_future/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end

    # Fetches service data for a given user
    def fetch_history_user_services(user_id)
      response = self.class.get("/services/get_history/#{user_id}", headers: @headers)

      if response.success?
        response.parsed_response.map(&:deep_symbolize_keys!)
      else
        Rails.logger.error "API Error: #{response.code} - #{response.message}"
        []
      end
    end
  end
end
