require "rails_helper"

RSpec.describe Consultation, type: :model do
  describe "validations" do
    it "lets two consultations link to one service" do
      service = create(:fliip_service, purchase_date: 1.day.ago)
      create(:consultation, fliip_user: service.fliip_user, fliip_service: service)

      expect(build(:consultation, user: create(:user), fliip_user: service.fliip_user, fliip_service: service)).to be_valid
    end

    it "refuses a service from another client" do
      consultation = build(:consultation, fliip_user: create(:fliip_user), fliip_service: create(:fliip_service, purchase_date: 1.day.ago))

      expect(consultation).not_to be_valid
      expect(consultation.errors[:fliip_service_id]).to include("ne correspond pas au client choisi")
    end

    it "refuses a service bought outside the link window, but keeps an older link on other edits" do
      travel_to Time.zone.local(2026, 5, 15, 10)
      service = create(:fliip_service, purchase_date: Date.new(2026, 6, 15))
      consultation = build(:consultation, user: create(:user), fliip_user: service.fliip_user, fliip_service: service, occurred_at: Time.zone.local(2026, 5, 15, 10))

      expect(consultation).not_to be_valid
      expect(consultation.errors[:fliip_service_id]).to include("doit avoir été acheté entre le 01/05/2026 et le 14/06/2026")

      consultation.fliip_service = nil
      consultation.save!
      consultation.update_columns(fliip_service_id: service.id)
      expect(consultation.reload.update(note: "suivi")).to be(true)
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
    it { is_expected.to validate_presence_of(:occurred_at) }
    it { is_expected.to validate_length_of(:note).is_at_most(10_000) }
    it { is_expected.to belong_to(:fliip_user).optional }
    it { is_expected.to belong_to(:fliip_service).optional }
  end

  describe "phone and email" do
    it "stores any common phone format as 10 digits" do
      [ "(514) 555-0142", "514.555.0142", "1 514 555 0142", "514 555 0142" ].each do |typed|
        consultation = create(:consultation, phone_number: typed)
        expect(consultation.phone_number).to eq("5145550142"), "from #{typed.inspect}"
      end
    end

    it "refuses 9 digits, and 11 digits not starting with 1" do
      [ "514 555 014", "25145550142", "abc" ].each do |typed|
        consultation = build(:consultation, phone_number: typed)
        expect(consultation).not_to be_valid, "from #{typed.inspect}"
        expect(consultation.errors[:phone_number]).to include("doit contenir 10 chiffres")
      end
    end

    it "needs a phone or an email" do
      consultation = build(:consultation, phone_number: " ", email: "")

      expect(consultation).not_to be_valid
      expect(consultation.errors[:base]).to include("Indiquez un téléphone ou un courriel.")
    end

    it "is valid with an email only, stored stripped and lower case" do
      consultation = create(:consultation, phone_number: nil, email: " Prospect@Exemple.CA ")

      expect(consultation.email).to eq("prospect@exemple.ca")
    end

    it "refuses an invalid email" do
      consultation = build(:consultation, email: "pas un courriel")

      expect(consultation).not_to be_valid
      expect(consultation.errors[:email]).to include("est invalide")
    end

    it "lets an existing consultation with an odd phone change its note" do
      consultation = create(:consultation)
      consultation.update_column(:phone_number, "555-12")

      expect(consultation.update(note: "Rappeler")).to be(true)
      expect(consultation.reload.phone_number).to eq("555-12")
    end
  end

  describe "presence" do
    it "is required on a new consultation" do
      consultation = build(:consultation, present: nil)

      expect(consultation).not_to be_valid
      expect(consultation.errors[:present]).to include("doit être indiqué")
    end

    it "lets an existing consultation without presence change its note" do
      consultation = create(:consultation)
      consultation.update_column(:present, nil)

      expect(consultation.update(note: "Rappeler")).to be(true)
    end
  end

  describe "status scopes" do
    it "splits confirmed from unconfirmed and finds those still to link" do
      pending   = create(:consultation)
      done      = create(:consultation, confirmed: true)
      client_only = create(:consultation, fliip_user: create(:fliip_user))
      service = create(:fliip_service, purchase_date: 1.day.ago)
      linked = create(:consultation, fliip_user: service.fliip_user, fliip_service: service)
      pending.update_columns(confirmed: nil)

      expect(described_class.unconfirmed).to contain_exactly(pending, client_only, linked)
      expect(described_class.confirmed).to contain_exactly(done)
      expect(described_class.to_link).to contain_exactly(pending, done, client_only)
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

  describe "#link_window" do
    it "runs from 14 days before to 30 days after the consultation" do
      consultation = build(:consultation, occurred_at: Time.zone.local(2026, 5, 15, 10))

      expect(consultation.link_window).to eq(Date.new(2026, 5, 1)..Date.new(2026, 6, 14))
    end
  end
end
