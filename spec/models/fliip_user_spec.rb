require "rails_helper"

RSpec.describe FliipUser, type: :model do
  describe "validations" do
    subject { build(:fliip_user) }

    it { is_expected.to validate_presence_of(:remote_id) }
    it { is_expected.to validate_uniqueness_of(:remote_id) }

    it "is backed by a unique index" do
      existing = create(:fliip_user)
      copy = build(:fliip_user, remote_id: existing.remote_id)
      expect { copy.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:fliip_contracts).dependent(:destroy) }
    it { is_expected.to have_many(:fliip_services).dependent(:destroy) }
    it { is_expected.to have_many(:sessions).dependent(:restrict_with_error) }
    it { is_expected.to have_many(:consultations).dependent(:destroy) }
  end

  describe ".with_any_services" do
    it "returns each client with at least one service once" do
      client = create(:fliip_user)
      create_list(:fliip_service, 2, fliip_user: client)
      create(:fliip_user)

      expect(described_class.with_any_services).to contain_exactly(client)
    end
  end

  describe ".with_service_after" do
    let(:cutoff) { Date.new(2026, 6, 1) }

    it "matches on start date, falling back to purchase date" do
      by_start    = create(:fliip_service, start_date: cutoff, purchase_date: cutoff - 60).fliip_user
      by_purchase = create(:fliip_service, start_date: nil, purchase_date: cutoff + 1).fliip_user
      create(:fliip_service, start_date: cutoff - 1, purchase_date: cutoff + 5)

      expect(described_class.with_service_after(cutoff)).to contain_exactly(by_start, by_purchase)
    end

    it "returns nothing for a blank date" do
      create(:fliip_service)

      expect(described_class.with_service_after(nil)).to be_empty
    end
  end

  describe "missing from Fliip" do
    let!(:present) { create(:fliip_user) }
    let!(:missing) { create(:fliip_user, :missing_from_fliip) }

    it "scopes users by the flag" do
      expect(described_class.missing_from_fliip).to contain_exactly(missing)
      expect(described_class.present_in_fliip).to include(present)
      expect(described_class.present_in_fliip).not_to include(missing)
    end

    it "answers missing_from_fliip?" do
      expect(missing).to be_missing_from_fliip
      expect(present).not_to be_missing_from_fliip
    end
  end

  describe "#full_name" do
    it "joins first and last name" do
      expect(build(:fliip_user, user_firstname: "Léa", user_lastname: "Roy").full_name).to eq("Léa Roy")
    end
  end

  describe "#most_recent_index_service" do
    let(:client) { create(:fliip_user) }

    it "prefers active over stopped over pending, ignoring other statuses" do
      create(:fliip_service, fliip_user: client, purchase_status: "C")
      pending = create(:fliip_service, fliip_user: client, purchase_status: "P")
      expect(client.reload.most_recent_index_service).to eq(pending)

      stopped = create(:fliip_service, fliip_user: client, purchase_status: "S")
      expect(client.reload.most_recent_index_service).to eq(stopped)

      active = create(:fliip_service, fliip_user: client, purchase_status: "A")
      expect(client.reload.most_recent_index_service).to eq(active)
    end

    it "picks the latest expiry, then the latest start, within a status" do
      create(:fliip_service, fliip_user: client, expire_date: 10.days.from_now.to_date)
      later = create(:fliip_service, fliip_user: client, expire_date: 20.days.from_now.to_date,
                                     start_date: 5.days.ago.to_date)
      create(:fliip_service, fliip_user: client, expire_date: 20.days.from_now.to_date,
                             start_date: 9.days.ago.to_date)

      expect(client.reload.most_recent_index_service).to eq(later)
    end

    it "is nil without services or with only inactive and cancelled ones" do
      expect(client.most_recent_index_service).to be_nil

      create(:fliip_service, fliip_user: client, purchase_status: "I")
      create(:fliip_service, fliip_user: client, purchase_status: "C")
      expect(client.reload.most_recent_index_service).to be_nil
    end
  end

  describe "#main_index_item" do
    let(:client) { create(:fliip_user) }

    it "prefers an active service" do
      service = create(:fliip_service, fliip_user: client, purchase_status: "A")
      create(:fliip_contract, fliip_user: client)

      expect(client.reload.main_index_item).to eq(service)
    end

    it "shows the active abonnement when no service is active" do
      create(:fliip_service, fliip_user: client, purchase_status: "S")
      contract = create(:fliip_contract, fliip_user: client)

      expect(client.reload.main_index_item).to eq(contract)
    end

    it "falls back to a stopped or planned service" do
      service = create(:fliip_service, fliip_user: client, purchase_status: "P")

      expect(client.reload.main_index_item).to eq(service)
    end

    it "is nil with neither" do
      expect(client.main_index_item).to be_nil
    end
  end

  describe "#best_active_contract_for_index" do
    let(:client) { create(:fliip_user) }

    it "picks the active contract ending last" do
      create(:fliip_contract, fliip_user: client, end_date: 10.days.from_now.to_date)
      latest = create(:fliip_contract, fliip_user: client, end_date: 90.days.from_now.to_date)
      create(:fliip_contract, :cancelled, fliip_user: client, end_date: 200.days.from_now.to_date)

      expect(client.reload.best_active_contract_for_index).to eq(latest)
    end

    it "is nil without an active contract" do
      create(:fliip_contract, :stopped, fliip_user: client)

      expect(client.reload.best_active_contract_for_index).to be_nil
    end
  end

  describe ".search" do
    let!(:gagne) do
      create(:fliip_user, remote_id: 77_001, user_firstname: "Ysolde", user_lastname: "Gagne",
        user_email: "ysolde.gagne@example.com", user_phone1: "(514) 555-0142", user_phone2: nil)
    end
    let!(:other) do
      create(:fliip_user, remote_id: 77_002, user_firstname: "Aldo", user_lastname: "Moreau",
        user_email: "aldo@example.com", user_phone1: nil, user_phone2: "438.555.9911")
    end

    it "returns nothing for a blank or one-letter query" do
      expect(described_class.search("")).to be_empty
      expect(described_class.search("  ")).to be_empty
      expect(described_class.search("G")).to be_empty
    end

    it "finds a last name without its accents" do
      expect(described_class.search("Gagné")).to contain_exactly(gagne)
    end

    it "finds an email by its start" do
      expect(described_class.search("ysolde.ga")).to contain_exactly(gagne)
    end

    it "finds the first phone in any format" do
      %w[5145550142 514-555-0142].push("555 0142").each do |query|
        expect(described_class.search(query)).to contain_exactly(gagne), "query #{query.inspect}"
      end
    end

    it "finds the second phone" do
      expect(described_class.search("438 555 9911")).to contain_exactly(other)
    end

    it "orders phone matches by first name, then last name" do
      gagne.update!(user_phone1: "514-555-0001")
      other.update!(user_phone2: "514-555-0002")

      expect(described_class.search("555-000").to_a).to eq([ other, gagne ])
    end

    it "finds a FliipUserID typed as digits" do
      expect(described_class.search("77002")).to contain_exactly(other)
    end

    it "doesn't search phones with fewer than 4 digits" do
      expect(described_class.search("555")).to be_empty
    end
  end

  describe "#staff?" do
    it "is true for any role other than user" do
      expect(build(:fliip_user, user_role: "admin")).to be_staff
      expect(build(:fliip_user, user_role: "user")).not_to be_staff
      expect(build(:fliip_user, user_role: nil)).not_to be_staff
    end
  end
end
