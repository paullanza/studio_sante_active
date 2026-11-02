require "rails_helper"

RSpec.describe FliipApi::ApiClient do
  let(:base)   { "https://static.fliipapp.com/api/v2" }
  let(:client) { described_class.new }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("FLIIP_API_KEY").and_return("test-key")
  end

  def json(body, status: 200, content_type: "application/json")
    { status: status, body: body.is_a?(String) ? body : body.to_json, headers: { "Content-Type" => content_type } }
  end

  def users(range)
    range.map { |id| { user_id: id.to_s, user_firstname: "Client #{id}" } }
  end

  it "raises when the API key is missing" do
    allow(ENV).to receive(:fetch).with("FLIIP_API_KEY").and_call_original
    stub_const("ENV", ENV.to_h.except("FLIIP_API_KEY"))

    expect { described_class.new }.to raise_error(KeyError)
  end

  it "sends the API key in the Authorization header" do
    stub = stub_request(:get, "#{base}/staff/get")
             .with(headers: { "Authorization" => "test-key" })
             .to_return(json([]))

    client.fetch_all_staff

    expect(stub).to have_been_requested
  end

  describe "#fetch_all_users" do
    it "pages with limit=100 and offset until a short page, oldest first" do
      stub_request(:get, "#{base}/users/get?limit=100&offset=0").to_return(json(users(1..100)))
      stub_request(:get, "#{base}/users/get?limit=100&offset=100").to_return(json(users(101..130)))

      result = client.fetch_all_users

      expect(result.size).to eq(130)
      expect(result.first).to eq(user_id: "130", user_firstname: "Client 130")
      expect(result.last[:user_id]).to eq("1")
    end

    it "stops at an empty page" do
      stub_request(:get, "#{base}/users/get?limit=2&offset=0").to_return(json(users(1..2)))
      stub_request(:get, "#{base}/users/get?limit=2&offset=2").to_return(json([]))

      expect(client.fetch_all_users(2).size).to eq(2)
    end

    it "returns what it has when a page fails, such as the 400 Fliip sends for a huge limit" do
      stub_request(:get, "#{base}/users/get?limit=100&offset=0").to_return(json(users(1..100)))
      stub_request(:get, "#{base}/users/get?limit=100&offset=100").to_return(status: 400, body: "")

      expect(client.fetch_all_users.size).to eq(100)

      stub_request(:get, "#{base}/users/get?limit=5000&offset=0").to_return(status: 400, body: "")
      expect(client.fetch_all_users(5000)).to eq([])
    end
  end

  describe "single records" do
    it "fetches a client's and a staff member's details with symbolized keys" do
      stub_request(:get, "#{base}/users/details/12").to_return(json({ user_id: "12", user_emergency_contact: { name: "Léa" } }))
      stub_request(:get, "#{base}/staff/details/34").to_return(json({ user_id: "34", user_role: "coach" }))

      expect(client.fetch_single_user(12)).to eq(user_id: "12", user_emergency_contact: { name: "Léa" })
      expect(client.fetch_single_staff(34)).to eq(user_id: "34", user_role: "coach")
    end
  end

  describe "contracts and services" do
    {
      fetch_user_contracts: "/contracts/get/7",
      fetch_future_user_contracts: "/contracts/get_future/7",
      fetch_history_user_contracts: "/contracts/get_history/7",
      fetch_user_services: "/services/get/7",
      fetch_future_user_services: "/services/get_future/7",
      fetch_history_user_services: "/services/get_history/7"
    }.each do |method, path|
      it "##{method} reads #{path}" do
        stub_request(:get, "#{base}#{path}").to_return(json([{ id: "1" }]))

        expect(client.public_send(method, 7)).to eq([{ id: "1" }])
      end
    end
  end

  describe "error responses" do
    it "log the status and return an empty array" do
      allow(Rails.logger).to receive(:error)
      stub_request(:get, "#{base}/users/details/12").to_return(status: 401, body: "")
      stub_request(:get, "#{base}/services/get/12").to_return(status: 500, body: "")
      stub_request(:get, "#{base}/staff/get").to_return(status: 403, body: "")

      expect(client.fetch_single_user(12)).to eq([])
      expect(client.fetch_user_services(12)).to eq([])
      expect(client.fetch_all_staff).to eq([])
      expect(Rails.logger).to have_received(:error).with(/API Error: 401/)
      expect(Rails.logger).to have_received(:error).with(/API Error: 500/)
    end
  end

  describe "encoding" do
    it "converts a body sent in ISO-8859-1 to valid UTF-8 when the charset is declared" do
      body = %([{"contract_id":"1","membership_name":"Abonnement r\xE9gulier"}]).b
      stub_request(:get, "#{base}/contracts/get/7")
        .to_return(json(body, content_type: "application/json; charset=iso-8859-1"))

      name = client.fetch_user_contracts(7).first[:membership_name]

      expect(name).to eq("Abonnement régulier")
      expect(name).to be_valid_encoding
    end
  end
end
