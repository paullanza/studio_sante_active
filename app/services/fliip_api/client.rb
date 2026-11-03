module FliipApi
  # Read-only HTTP client for the Fliip API (docs/fliip_api/).
  #
  # Every method returns parsed data with symbol keys, or raises:
  # - FliipApi::NotFound on 400 (Fliip doesn't know that user id)
  # - FliipApi::Unavailable when retries run out, on any other error status,
  #   or when the body isn't the JSON shape expected.
  # It never returns [] on failure, and a failed page fails the whole list.
  class Client
    BASE_URL = "https://static.fliipapp.com/api/v2".freeze
    PAGE_SIZE = 100 # Fliip rejects large limits with an empty 400
    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 30
    RETRIES = 2

    # A 5xx or 429 worth retrying.
    class RetryableResponse < StandardError; end
    private_constant :RetryableResponse

    RETRYABLE_ERRORS = [
      Timeout::Error, SocketError, OpenSSL::SSL::SSLError,
      Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::EHOSTUNREACH, Errno::ETIMEDOUT
    ].freeze

    def initialize(api_key: ENV.fetch("FLIIP_API_KEY"), sleeper: ->(seconds) { sleep(seconds) })
      @headers = { "Authorization" => api_key }
      @sleeper = sleeper
    end

    # Pages of clients, newest first (Fliip sorts by user_id descending).
    # Lazy, so a caller can stop early.
    def client_pages
      pages("/users/get")
    end

    def clients
      client_pages.flat_map(&:itself)
    end

    def staff
      pages("/staff/get").flat_map(&:itself)
    end

    def client(remote_id)
      get_object("/users/details/#{remote_id}")
    end

    def staff_member(remote_id)
      get_object("/staff/details/#{remote_id}")
    end

    # get_history returns every service (active, suspended, planned,
    # inactive and cancelled), so one call covers a user's services.
    def services(remote_id)
      get_list("/services/get_history/#{remote_id}")
    end

    # The three contract endpoints don't overlap: active and suspended,
    # planned, then inactive and cancelled.
    def contracts(remote_id)
      %w[get get_future get_history].flat_map { |endpoint| get_list("/contracts/#{endpoint}/#{remote_id}") }
    end

    private

    def pages(path)
      Enumerator.new do |yielder|
        offset = 0
        loop do
          page = get_list("#{path}?limit=#{PAGE_SIZE}&offset=#{offset}")
          yielder << page unless page.empty?
          break if page.size < PAGE_SIZE

          offset += PAGE_SIZE
        end
      end
    end

    def get_list(path)
      body = get(path)
      raise Unavailable, "Expected a list from #{path}, got #{body.class}" unless body.is_a?(Array)

      body.map { |row| symbolize(row, path) }
    end

    def get_object(path)
      symbolize(get(path), path)
    end

    def symbolize(row, path)
      raise Unavailable, "Expected an object from #{path}, got #{row.class}" unless row.is_a?(Hash)

      row.deep_symbolize_keys
    end

    def get(path)
      attempt = 0
      begin
        attempt += 1
        response = HTTParty.get(BASE_URL + path, headers: @headers,
                                open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
        handle(response, path)
      rescue *RETRYABLE_ERRORS, RetryableResponse => e
        if attempt <= RETRIES
          Rails.logger.warn("[Fliip] #{path}: #{e.message}, retry #{attempt}/#{RETRIES}")
          @sleeper.call(2**(attempt - 1))
          retry
        end
        raise Unavailable, "#{path}: #{e.message} (after #{RETRIES} retries)"
      end
    end

    def handle(response, path)
      code = response.code
      raise NotFound, "#{path}: 400 (unknown user id)" if code == 400
      raise RetryableResponse, "HTTP #{code}" if code == 429 || code >= 500
      raise Unavailable, "#{path}: HTTP #{code}" unless code == 200

      parse(response.body, path)
    end

    # Undeclared non-UTF-8 text is scrubbed so it can't break the parse,
    # the logger or the save.
    def parse(body, path)
      JSON.parse(body.to_s.dup.force_encoding(Encoding::UTF_8).scrub)
    rescue JSON::ParserError
      raise Unavailable, "#{path}: response is not JSON"
    end
  end
end
