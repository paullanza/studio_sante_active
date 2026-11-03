require "rails_helper"

RSpec.describe FliipApi::Client do
  let(:base)   { "https://static.fliipapp.com/api/v2" }
  let(:sleeps) { [] }
  let(:client) { described_class.new(api_key: "test-key", sleeper: ->(s) { sleeps << s }) }

  def json(body, status: 200)
    { status: status, body: body.is_a?(String) ? body : body.to_json, headers: { "Content-Type" => "application/json" } }
  end

  def rows(range)
    range.map { |id| { user_id: id.to_s } }
  end

  it "reads the API key from FLIIP_API_KEY by default" do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("FLIIP_API_KEY").and_return("env-key")
    stub = stub_request(:get, "#{base}/services/get_history/1").with(headers: { "Authorization" => "env-key" }).to_return(json([]))

    described_class.new.services(1)

    expect(stub).to have_been_requested
  end

  describe "lists" do
    it "pages clients with limit=100 and offset, keeping Fliip's newest-first order" do
      stub_request(:get, "#{base}/users/get?limit=100&offset=0").to_return(json(rows(1..100).reverse))
      stub_request(:get, "#{base}/users/get?limit=100&offset=100").to_return(json(rows(101..130).reverse))

      result = client.clients

      expect(result.size).to eq(130)
      expect(result.first).to eq(user_id: "100")
    end

    it "lets a caller stop paging early" do
      first = stub_request(:get, "#{base}/users/get?limit=100&offset=0").to_return(json(rows(1..100)))
      second = stub_request(:get, "#{base}/users/get?limit=100&offset=100")

      expect(client.client_pages.first.size).to eq(100)
      expect(first).to have_been_requested
      expect(second).not_to have_been_requested
    end

    it "stops at an empty page" do
      stub_request(:get, "#{base}/staff/get?limit=100&offset=0").to_return(json(rows(1..100)))
      stub_request(:get, "#{base}/staff/get?limit=100&offset=100").to_return(json([]))

      expect(client.staff.size).to eq(100)
    end

    it "fails the whole list when a page fails" do
      stub_request(:get, "#{base}/users/get?limit=100&offset=0").to_return(json(rows(1..100)))
      stub_request(:get, "#{base}/users/get?limit=100&offset=100").to_return(status: 503, body: "")

      expect { client.clients }.to raise_error(FliipApi::Unavailable, /503/)
    end
  end

  describe "per-user calls" do
    it "reads services from get_history only" do
      stub_request(:get, "#{base}/services/get_history/7").to_return(json([ { service_purchase_id: "1" } ]))

      expect(client.services(7)).to eq([ { service_purchase_id: "1" } ])
    end

    it "combines the three contract endpoints" do
      %w[get get_future get_history].each_with_index do |endpoint, i|
        stub_request(:get, "#{base}/contracts/#{endpoint}/7").to_return(json([ { contract_id: i.to_s } ]))
      end

      expect(client.contracts(7).map { |c| c[:contract_id] }).to eq(%w[0 1 2])
    end

    it "returns a client's details as a hash" do
      stub_request(:get, "#{base}/users/details/7").to_return(json({ user_id: "7" }))

      expect(client.client(7)).to eq(user_id: "7")
    end

    it "returns a staff member's details as a hash" do
      stub_request(:get, "#{base}/staff/details/7").to_return(json({ user_id: "7" }))

      expect(client.staff_member(7)).to eq(user_id: "7")
    end

    it "raises NotFound on 400 without retrying" do
      stub = stub_request(:get, "#{base}/users/details/999").to_return(status: 400, body: "")

      expect { client.client(999) }.to raise_error(FliipApi::NotFound)
      expect(stub).to have_been_requested.once
    end
  end

  describe "failures" do
    it "retries a 5xx twice with backoff, then succeeds" do
      stub_request(:get, "#{base}/services/get_history/7")
        .to_return({ status: 502, body: "" }, { status: 500, body: "" }, json([]))

      expect(client.services(7)).to eq([])
      expect(sleeps).to eq([ 1, 2 ])
    end

    it "retries a 429" do
      stub_request(:get, "#{base}/services/get_history/7").to_return({ status: 429, body: "" }, json([]))

      expect(client.services(7)).to eq([])
    end

    it "raises Unavailable when retries run out" do
      stub = stub_request(:get, "#{base}/services/get_history/7").to_return(status: 503, body: "")

      expect { client.services(7) }.to raise_error(FliipApi::Unavailable, /after 2 retries/)
      expect(stub).to have_been_requested.times(3)
    end

    it "retries timeouts, then raises Unavailable" do
      stub_request(:get, "#{base}/services/get_history/7").to_timeout

      expect { client.services(7) }.to raise_error(FliipApi::Unavailable)
      expect(sleeps.size).to eq(2)
    end

    it "retries connection errors" do
      stub_request(:get, "#{base}/services/get_history/7").to_raise(Errno::ECONNRESET).then.to_return(json([]))

      expect(client.services(7)).to eq([])
    end

    it "raises Unavailable without retrying on other error statuses" do
      stub = stub_request(:get, "#{base}/services/get_history/7").to_return(status: 401, body: "")

      expect { client.services(7) }.to raise_error(FliipApi::Unavailable, /401/)
      expect(stub).to have_been_requested.once
    end

    it "raises Unavailable when the body isn't JSON" do
      stub_request(:get, "#{base}/services/get_history/7").to_return(status: 200, body: "<html>oops</html>")

      expect { client.services(7) }.to raise_error(FliipApi::Unavailable, /not JSON/)
    end

    it "raises Unavailable when a list endpoint returns an object" do
      stub_request(:get, "#{base}/services/get_history/7").to_return(json({ error: true }))

      expect { client.services(7) }.to raise_error(FliipApi::Unavailable, /Expected a list/)
    end
  end

  it "scrubs invalid UTF-8 instead of failing" do
    body = "[{\"service_name\":\"Caf\xE9\"}]".b
    stub_request(:get, "#{base}/services/get_history/7").to_return(status: 200, body: body)

    name = client.services(7).first[:service_name]

    expect(name).to be_valid_encoding
    expect(name).to start_with("Caf")
  end
end
