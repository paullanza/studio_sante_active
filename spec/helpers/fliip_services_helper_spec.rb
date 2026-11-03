require "rails_helper"

RSpec.describe FliipServicesHelper, type: :helper do
  describe "#missing_from_fliip_badge" do
    it "shows a badge with the date for a flagged record" do
      service = build(:fliip_service, missing_from_fliip_at: Time.zone.local(2026, 11, 2, 10))

      expect(helper.missing_from_fliip_badge(service)).to include("Retiré de Fliip", "02/11/2026")
    end

    it "renders nothing for a record still in Fliip" do
      expect(helper.missing_from_fliip_badge(build(:fliip_service))).to be_nil
    end
  end

  describe "#purchase_status_badge_class" do
    it "maps each purchase status" do
      expect(%w[A P S C I].map { |s| helper.purchase_status_badge_class(s) })
        .to eq(["bg-success", "bg-info text-dark", "bg-warning text-dark", "bg-danger", "bg-secondary"])
    end
  end

  describe "#svc_time_range_label" do
    it "shows the known dates" do
      expect(helper.svc_time_range_label(build(:fliip_service, start_date: Date.new(2026, 1, 1), expire_date: Date.new(2026, 2, 1))))
        .to eq("01/01/2026–01/02/2026")
      expect(helper.svc_time_range_label(build(:fliip_service, start_date: Date.new(2026, 1, 1), expire_date: nil))).to eq("01/01/2026–?")
      expect(helper.svc_time_range_label(build(:fliip_service, start_date: nil, expire_date: Date.new(2026, 2, 1)))).to eq("?–01/02/2026")
      expect(helper.svc_time_range_label(build(:fliip_service, start_date: nil, expire_date: nil))).to eq("—")
    end
  end

  describe "#svc_time_progress_percent" do
    it "uses the purchase date when there is no start date" do
      travel_to Date.new(2026, 1, 6) do
        svc = build(:fliip_service, start_date: nil, purchase_date: Time.zone.local(2026, 1, 1), expire_date: Date.new(2026, 1, 11))

        expect(helper.svc_time_progress_percent(svc)).to eq(50)
      end
    end

    it "is 0 without a usable range" do
      expect(helper.svc_time_progress_percent(build(:fliip_service, expire_date: nil))).to eq(0)
    end
  end

  describe "#progress_color_classes" do
    it "goes from grey to green, yellow, orange and red" do
      expect(helper.progress_color_classes(0)).to eq(%w[bg-secondary text-white])
      expect(helper.progress_color_classes(49)).to eq(%w[bg-success text-white])
      expect(helper.progress_color_classes(50)).to eq(%w[bg-warning text-dark])
      expect(helper.progress_color_classes(75)).to eq(%w[bg-orange text-dark])
      expect(helper.progress_color_classes(95)).to eq(%w[bg-danger text-white])
    end
  end

  describe "#fmt1" do
    it "formats with one decimal" do
      expect(helper.fmt1(2)).to eq("2.0")
      expect(helper.fmt1(nil)).to eq("0.0")
    end
  end

  describe "paid progress" do
    let(:definition) { create(:service_definition, paid_sessions: 4, free_sessions: 2) }
    let(:svc)        { create(:fliip_service, service_definition: definition) }

    it "is complete once every paid session is used" do
      create(:service_usage_adjustment, fliip_service: svc, paid_used_delta: 4)

      expect(helper.paid_progress_complete?(svc, 100)).to be true
      expect(helper.paid_progress_label(svc, 100)).to eq("Complet - 4.0/4.0 100%")
      expect(helper.paid_progress_bg_class(svc, 100, 10)).to eq("bg-success")
    end

    it "otherwise shows the compact usage and the discrepancy color" do
      create(:service_usage_adjustment, fliip_service: svc, paid_used_delta: 1)

      expect(helper.paid_progress_complete?(svc, 25)).to be false
      expect(helper.paid_progress_label(svc, 25)).to eq("1.0/4.0 [0.0/2.0 absences] • 25%")
      expect(helper.paid_progress_bg_class(svc, 25, 80)).to eq("bg-danger")
    end

    it "is never complete without an allowance" do
      expect(helper.paid_progress_complete?(create(:fliip_service, :without_definition), 100)).to be false
    end
  end
end
