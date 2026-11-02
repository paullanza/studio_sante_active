require "rails_helper"

RSpec.describe Consultation, type: :model do
  describe "validations" do
    it "allows a service to be linked to only one consultation" do
      service = create(:fliip_service)
      create(:consultation, fliip_service: service)
      other = build(:consultation, fliip_service: service)

      expect(other).not_to be_valid
      expect(other.errors[:fliip_service_id]).to be_present
    end

    it "defaults created_by to the responsible user" do
      consultation = create(:consultation)
      expect(consultation.created_by).to eq(consultation.user)
    end
  end

  describe ".confirm" do
    it "confirms unconfirmed consultations" do
      consultation = create(:consultation)

      expect(described_class.confirm([consultation.id])).to eq(1)
      expect(consultation.reload).to be_confirmed
    end
  end

  describe "required fields" do
    subject { build(:consultation) }

    it { is_expected.to validate_presence_of(:first_name) }
    it { is_expected.to validate_presence_of(:last_name) }
    it { is_expected.to validate_presence_of(:phone_number) }
    it { is_expected.to validate_presence_of(:occurred_at) }
    it { is_expected.to validate_length_of(:note).is_at_most(10_000) }
    it { is_expected.to belong_to(:fliip_user).optional }
    it { is_expected.to belong_to(:fliip_service).optional }
  end

  describe "status scopes" do
    it "splits confirmed from unconfirmed and finds unassociated ones" do
      pending   = create(:consultation)
      done      = create(:consultation, confirmed: true)
      linked    = create(:consultation, fliip_user: create(:fliip_user))
      pending.update_columns(confirmed: nil)

      expect(described_class.unconfirmed).to contain_exactly(pending, linked)
      expect(described_class.confirmed).to contain_exactly(done)
      expect(described_class.unassociated).to contain_exactly(pending, done)
    end

    it "orders by occurred_at, newest first" do
      older = create(:consultation, occurred_at: 3.days.ago)
      newer = create(:consultation, occurred_at: 1.day.ago)

      expect(described_class.order_by_occurred_at_desc).to eq([newer, older])
    end
  end

  describe "filters" do
    let(:staff)  { create(:user) }
    let!(:early) do
      create(:consultation, user: staff, first_name: "Émilie", last_name: "Gagnon", present: true,
                            occurred_at: Time.zone.local(2026, 10, 5, 10))
    end
    let!(:late) do
      create(:consultation, first_name: "Marc", last_name: "Roy", present: false,
                            occurred_at: Time.zone.local(2026, 10, 20, 10))
    end

    it "filter by employee, dates and presence" do
      expect(described_class.by_employee(staff.id)).to contain_exactly(early)
      expect(described_class.by_employee(nil)).to contain_exactly(early, late)
      expect(described_class.date_between("2026-10-15", nil)).to contain_exactly(late)
      expect(described_class.present_value("yes")).to contain_exactly(early)
      expect(described_class.present_value(%w[yes no])).to contain_exactly(early, late)

      early.update_columns(created_at: Time.zone.local(2026, 9, 1))
      expect(described_class.created_between(nil, "2026-09-02")).to contain_exactly(early)
    end

    it ".apply_filters searches names without accents" do
      expect(described_class.apply_filters(q: "emilie")).to contain_exactly(early)
      expect(described_class.apply_filters(q: "Roy", present: ["no"], consultation_date_from: "2026-10-01"))
        .to contain_exactly(late)
    end
  end

  describe "#full_name" do
    it "joins the names and tolerates a missing one" do
      expect(build(:consultation, first_name: "Léa", last_name: "Roy").full_name).to eq("Léa Roy")
      expect(build(:consultation, first_name: "Léa", last_name: nil).full_name).to eq("Léa")
    end
  end

  describe "#association_start_window" do
    it "runs from 14 days before to 3 months after the consultation" do
      consultation = build(:consultation, occurred_at: Time.zone.local(2026, 5, 15, 10))

      expect(consultation.association_start_window).to eq(Date.new(2026, 5, 1)..Date.new(2026, 8, 15))
    end
  end
end
