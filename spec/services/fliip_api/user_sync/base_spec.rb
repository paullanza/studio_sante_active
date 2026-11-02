require "rails_helper"

RSpec.describe FliipApi::UserSync::Base do
  let(:api) { instance_double(FliipApi::ApiClient) }
  let(:sync) { described_class.new }

  before do
    allow(FliipApi::ApiClient).to receive(:new).and_return(api)
    allow(FliipApi::UserSync::ContractSync).to receive(:call)
    allow(FliipApi::UserSync::ServiceSync).to receive(:call)
  end

  describe ".completion_message" do
    let(:start) { Time.zone.local(2026, 1, 1, 10, 0, 0) }

    it "reports elapsed time and pluralized counts" do
      message = described_class.completion_message(
        start_time: start, end_time: start + 3725, new_users: 1, updated_users: 2
      )

      expect(message).to eq("Sync complete: Elapsed time: 1 hours, 2 minutes, 5 seconds | 1 new user, 2 updated users.")
    end

    it "creates missing service definitions" do
      allow(ServiceDefinition).to receive(:create_missing_definitions!)

      described_class.completion_message(start_time: start, end_time: start, new_users: 0, updated_users: 0)

      expect(ServiceDefinition).to have_received(:create_missing_definitions!)
    end
  end

  describe "#upsert_user" do
    let(:data) { { user_id: "321", user_firstname: "Léa", user_lastname: "Roy", user_role: "user", member_since: "2024-02-03" } }

    it "creates a new client and syncs their contracts and services" do
      expect(sync.send(:upsert_user, data)).to eq("new")

      client = FliipUser.find_by!(remote_id: 321)
      expect(client.member_since).to eq(Date.new(2024, 2, 3))
      expect(FliipApi::UserSync::ContractSync).to have_received(:call).with(client)
      expect(FliipApi::UserSync::ServiceSync).to have_received(:call).with(client)
    end

    it "reports updated or unchanged for an existing client" do
      sync.send(:upsert_user, data)

      expect(sync.send(:upsert_user, data)).to eq("unchanged")
      expect(sync.send(:upsert_user, data.merge(user_lastname: "Gagnon"))).to eq("updated")
      expect(FliipUser.sole.user_lastname).to eq("Gagnon")
    end

    it "still syncs contracts and services when the client is unchanged" do
      sync.send(:upsert_user, data)
      sync.send(:upsert_user, data)

      expect(FliipApi::UserSync::ServiceSync).to have_received(:call).twice
    end
  end

  it "remembers the highest remote_id already stored" do
    create(:fliip_user, remote_id: 50)
    create(:fliip_user, remote_id: 75)

    expect(sync.instance_variable_get(:@last_remote_id)).to eq(75)
  end

  describe "date parsing" do
    it "returns nil for blank or invalid values" do
      expect(sync.send(:parse_date, "2026-03-04")).to eq(Date.new(2026, 3, 4))
      expect(sync.send(:parse_date, "")).to be_nil
      expect(sync.send(:parse_date, "nope")).to be_nil
      expect(sync.send(:parse_datetime, "2026-03-04 08:30:00")).to eq(DateTime.new(2026, 3, 4, 8, 30))
      expect(sync.send(:parse_datetime, "nope")).to be_nil
    end
  end
end
