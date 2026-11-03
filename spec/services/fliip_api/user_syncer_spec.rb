require "rails_helper"

RSpec.describe FliipApi::UserSyncer do
  let(:client) { instance_double(FliipApi::Client) }
  let(:syncer) { described_class.new(client: client) }
  let(:row)    { { user_id: "500", user_role: "user", user_firstname: "Ana", user_status: "active" } }

  def service_row(id, **attrs)
    { service_purchase_id: id.to_s, purchase_status: "A", service_id: "444", service_name: "Privé",
      start_date: "2026-10-01", expire_date: "2027-10-01", purchase_date: "2026-10-01 10:00:00" }.merge(attrs)
  end

  def contract_row(id, **attrs)
    { contract_id: id.to_s, status: "A", start_date: "2026-10-01", end_date: "2027-10-01" }.merge(attrs)
  end

  def stub_fliip(services: [], contracts: [], remote_id: 500)
    allow(client).to receive(:services).with(remote_id).and_return(services)
    allow(client).to receive(:contracts).with(remote_id).and_return(contracts)
  end

  context "with a user new to the app" do
    it "creates the user, services, contracts and a 0/0 definition" do
      stub_fliip(services: [ service_row(1) ], contracts: [ contract_row(2) ])

      result = syncer.call(row)

      user = FliipUser.find_by!(remote_id: 500)
      expect(user.fliip_services.pluck(:remote_purchase_id)).to eq([ 1 ])
      expect(user.fliip_contracts.pluck(:remote_contract_id)).to eq([ 2 ])
      expect(ServiceDefinition.find_by!(service_id: 444)).to have_attributes(service_name: "Privé", paid_sessions: 0)
      expect(result).to have_attributes(user_change: :created, definitions_created: 1)
      expect(result.services).to include(created: 1, flagged: 0)
      expect(result).to be_changed
    end
  end

  context "with a user already in sync" do
    it "writes nothing and reports unchanged" do
      stub_fliip(services: [ service_row(1) ], contracts: [ contract_row(2) ])
      syncer.call(row)

      result = syncer.call(row)

      expect(result.user_change).to eq(:unchanged)
      expect(result.services).to include(created: 0, updated: 0, unchanged: 1)
      expect(result.contracts).to include(unchanged: 1)
      expect(result).not_to be_changed
    end
  end

  context "when Fliip changed a record" do
    it "updates it" do
      stub_fliip(services: [ service_row(1) ])
      syncer.call(row)
      stub_fliip(services: [ service_row(1, purchase_status: "C") ])

      result = syncer.call(row.merge(user_status: "canceled"))

      expect(FliipService.find_by!(remote_purchase_id: 1).purchase_status).to eq("C")
      expect(FliipUser.find_by!(remote_id: 500).user_status).to eq("canceled")
      expect(result.user_change).to eq(:updated)
      expect(result.services[:updated]).to eq(1)
    end
  end

  context "when Fliip lists a record under this user that was stored under someone else" do
    it "moves it" do
      other = create(:fliip_user)
      service = create(:fliip_service, fliip_user: other, remote_purchase_id: 1)
      stub_fliip(services: [ service_row(1) ])

      syncer.call(row)

      expect(service.reload.fliip_user.remote_id).to eq(500)
    end
  end

  context "when Fliip stopped returning a record" do
    it "flags it, and clears the flag if it comes back" do
      stub_fliip(services: [ service_row(1), service_row(3) ], contracts: [ contract_row(2) ])
      syncer.call(row)
      stub_fliip(services: [ service_row(1) ])

      result = syncer.call(row)

      expect(FliipService.find_by!(remote_purchase_id: 3)).to be_missing_from_fliip
      expect(FliipContract.find_by!(remote_contract_id: 2)).to be_missing_from_fliip
      expect(FliipService.find_by!(remote_purchase_id: 1)).not_to be_missing_from_fliip
      expect(result.services[:flagged]).to eq(1)

      stub_fliip(services: [ service_row(1), service_row(3) ], contracts: [ contract_row(2) ])
      syncer.call(row)

      expect(FliipService.find_by!(remote_purchase_id: 3)).not_to be_missing_from_fliip
      expect(FliipContract.find_by!(remote_contract_id: 2)).not_to be_missing_from_fliip
    end

    it "keeps the sessions on a flagged service" do
      stub_fliip(services: [ service_row(1) ])
      syncer.call(row)
      service = FliipService.find_by!(remote_purchase_id: 1)
      service.service_definition.update!(paid_sessions: 10)
      create(:session, fliip_service: service, occurred_at: 1.day.ago)
      stub_fliip(services: [])

      syncer.call(row)

      expect(service.reload).to be_missing_from_fliip
      expect(service.sessions.count).to eq(1)
    end
  end

  context "when Fliip is unavailable" do
    it "changes nothing and re-raises" do
      user = create(:fliip_user, remote_id: 500, user_firstname: "Old")
      create(:fliip_service, fliip_user: user, remote_purchase_id: 1)
      allow(client).to receive(:services).with(500).and_return([])
      allow(client).to receive(:contracts).with(500).and_raise(FliipApi::Unavailable, "down")

      expect { syncer.call(row) }.to raise_error(FliipApi::Unavailable)
      expect(user.reload.user_firstname).to eq("Old")
      expect(FliipService.find_by!(remote_purchase_id: 1)).not_to be_missing_from_fliip
    end
  end

  context "when Fliip doesn't know the user" do
    it "flags the user and their records, then re-raises" do
      user = create(:fliip_user, remote_id: 500)
      service = create(:fliip_service, fliip_user: user)
      contract = create(:fliip_contract, fliip_user: user)
      allow(client).to receive(:services).with(500).and_raise(FliipApi::NotFound, "400")

      expect { syncer.call(row) }.to raise_error(FliipApi::NotFound)
      expect([ user, service, contract ].map { |r| r.reload.missing_from_fliip? }).to all(be(true))
    end
  end

  describe "#call_by_remote_id" do
    it "syncs a client from their details" do
      allow(client).to receive(:client).with(500).and_return(row)
      stub_fliip

      syncer.call_by_remote_id("500")

      expect(FliipUser.find_by!(remote_id: 500).user_firstname).to eq("Ana")
    end

    it "uses staff details for known staff, keeping the stored status" do
      create(:fliip_user, remote_id: 500, user_role: "coach", user_status: "active")
      allow(client).to receive(:staff_member).with(500).and_return({ user_id: "500", user_role: "coach", user_firstname: "Jo" })
      stub_fliip

      syncer.call_by_remote_id(500)

      expect(FliipUser.find_by!(remote_id: 500)).to have_attributes(user_firstname: "Jo", user_status: "active")
    end

    it "falls back to staff details for an unknown id" do
      allow(client).to receive(:client).with(500).and_raise(FliipApi::NotFound, "400")
      allow(client).to receive(:staff_member).with(500).and_return({ user_id: "500", user_role: "coach" })
      stub_fliip

      syncer.call_by_remote_id(500)

      expect(FliipUser.find_by!(remote_id: 500)).to be_staff
    end

    it "flags a known client Fliip no longer knows" do
      user = create(:fliip_user, remote_id: 500)
      allow(client).to receive(:client).with(500).and_raise(FliipApi::NotFound, "400")

      expect { syncer.call_by_remote_id(500) }.to raise_error(FliipApi::NotFound)
      expect(user.reload).to be_missing_from_fliip
    end
  end
end
