require "rails_helper"

RSpec.describe ServiceBadgesHelper, type: :helper do
  def badge(label, modifier)
    %(<span class="badge #{modifier}">#{label}</span>)
  end

  describe "#service_status_badge" do
    it "says « Retiré de Fliip » when the service is removed from Fliip" do
      svc = build(:fliip_service, :missing_from_fliip)

      expect(helper.service_status_badge(svc)).to eq(badge("Retiré de Fliip", "badge--retire"))
    end

    it "says « Retiré de Fliip » when the client is removed from Fliip" do
      svc = build(:fliip_service, fliip_user: build(:fliip_user, :missing_from_fliip))

      expect(helper.service_status_badge(svc)).to eq(badge("Retiré de Fliip", "badge--retire"))
    end

    it "says « Toutes les séances utilisées » when a set allocation is used up" do
      svc = build(:fliip_service, service_definition: build(:service_definition, paid_sessions: 2))
      allow(svc).to receive(:paid_used_total).and_return(2.0)

      expect(helper.service_status_badge(svc)).to eq(badge("Toutes les séances utilisées", "badge--neutral"))
    end

    it "shows the status when the allocation isn't set" do
      svc = build(:fliip_service, :without_definition)

      expect(helper.service_status_badge(svc)).to eq(badge("Actif", "badge--chargee"))
    end

    {
      "A" => [ "Actif", "badge--chargee" ],
      "P" => [ "Planifié", "badge--absence" ],
      "S" => [ "Suspendu", "badge--moins24" ],
      "I" => [ "Inactif", "badge--neutral" ],
      "C" => [ "Annulé", "badge--neutral" ],
      "X" => [ "Inconnu", "badge--neutral" ]
    }.each do |code, (label, modifier)|
      it "shows #{code} as « #{label} »" do
        svc = build(:fliip_service, purchase_status: code)

        expect(helper.service_status_badge(svc)).to eq(badge(label, modifier))
      end
    end
  end

  describe "#contract_status_badge" do
    it "shows an active abonnement" do
      expect(helper.contract_status_badge(build(:fliip_contract, status: "A"))).to eq(badge("Actif", "badge--chargee"))
    end

    it "shows an inactive abonnement as neutral" do
      expect(helper.contract_status_badge(build(:fliip_contract, :inactive))).to eq(badge("Inactif", "badge--neutral"))
    end

    it "says « Retiré de Fliip » when the abonnement is removed from Fliip" do
      contract = build(:fliip_contract, :missing_from_fliip)

      expect(helper.contract_status_badge(contract)).to eq(badge("Retiré de Fliip", "badge--retire"))
    end
  end
end
