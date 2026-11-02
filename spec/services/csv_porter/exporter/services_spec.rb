require "rails_helper"

RSpec.describe CsvPorter::Exporter::Services do
  let(:client)     { create(:fliip_user, remote_id: 4321, user_firstname: "Léa", user_lastname: "Roy") }
  let(:definition) { create(:service_definition, paid_sessions: 10, free_sessions: 2) }
  let!(:service) do
    create(:fliip_service, fliip_user: client, service_definition: definition, remote_purchase_id: 777,
                           service_name: "Kinésiologie", purchase_status: "A",
                           start_date: Date.new(2026, 9, 1), expire_date: Date.new(2026, 12, 1))
  end

  def rows(csv)
    CSV.parse(csv, headers: true).map(&:to_h)
  end

  it "names the file with a timestamp" do
    travel_to Time.zone.local(2026, 11, 2, 9, 5, 7) do
      _csv, filename = described_class.call

      expect(filename).to eq("clients_services_20261102-090507.csv")
    end
  end

  it "writes one row per service with usage from sessions and adjustments" do
    create(:session, fliip_service: service, present: true, duration: 1.0, occurred_at: 2.days.ago.change(min: 0))
    create(:session, fliip_service: service, present: false, duration: 0.5, occurred_at: 1.day.ago.change(min: 0))
    create(:service_usage_adjustment, fliip_service: service, paid_used_delta: 2, free_used_delta: 0, bonus_sessions: 3)

    csv, = described_class.call

    expect(CSV.parse(csv).first).to eq(described_class::HEADERS)
    expect(rows(csv)).to eq([{
      "client_id" => client.id.to_s, "client_remote_id" => "4321", "client_name" => "Léa Roy",
      "service_id" => service.id.to_s, "service_remote_purchase_id" => "777",
      "service_name" => "Kinésiologie", "purchase_status" => "A",
      "start_date" => "01/09/2026", "expire_date" => "01/12/2026",
      "paid_used" => "3.0", "paid_included" => "10", "free_used" => "0.5", "free_included" => "2",
      "bonus_sessions" => "3.0"
    }])
  end

  it "leaves allowance columns blank for a service without a definition" do
    service.destroy
    create(:fliip_service, :without_definition, fliip_user: client, expire_date: nil)

    row = rows(described_class.call.first).sole

    expect(row.values_at("paid_included", "free_included", "expire_date")).to eq([nil, nil, nil])
    expect(row.values_at("paid_used", "free_used", "bonus_sessions")).to eq(%w[0.0 0.0 0.0])
  end
end
