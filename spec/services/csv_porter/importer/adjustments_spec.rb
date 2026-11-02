require "rails_helper"

RSpec.describe CsvPorter::Importer::Adjustments do
  let(:employee) { create(:user) }
  let(:service)  { create(:fliip_service) }

  def import(csv_text)
    rows = CSV.parse(csv_text, headers: true).map(&:to_h)
    described_class.call(rows: rows, employee_id: employee.id.to_s)
  end

  it "creates an adjustment per valid row for the chosen employee" do
    result = import(<<~CSV)
      service_id,paid_used,free_used,bonus_sessions
      #{service.id},2,0.5,
      #{service.id},,,1
    CSV

    expect(result).to be_success
    expect(result.created).to eq(2)
    expect(service.service_usage_adjustments.pluck(:paid_used_delta, :free_used_delta, :bonus_sessions))
      .to contain_exactly([2.0, 0.5, 0.0], [0.0, 0.0, 1.0])
    expect(ServiceUsageAdjustment.pluck(:user_id).uniq).to eq([employee.id])
  end

  it "reports invalid rows by spreadsheet line and keeps importing the rest" do
    result = import(<<~CSV)
      service_id,paid_used,free_used,bonus_sessions
      ,1,0,0
      999999,1,0,0
      #{service.id},0,0,0
      #{service.id},abc,1,0
    CSV

    expect(result).not_to be_success
    expect(result.created).to eq(1)
    expect(result.errors).to eq([
      "Row 2: service_id is missing",
      "Row 3: FliipService #999999 not found",
      "Row 4: Validation failed: Provide at least one non-zero adjustment."
    ])
    expect(ServiceUsageAdjustment.sole.free_used_delta).to eq(1.0)
  end

  it "imports a repeated row twice (rows are not de-duplicated)" do
    result = import(<<~CSV)
      service_id,paid_used,free_used,bonus_sessions
      #{service.id},1,0,0
      #{service.id},1,0,0
    CSV

    expect(result.created).to eq(2)
    expect(service.paid_used_adjustment).to eq(2.0)
  end

  it "accepts symbol keys" do
    result = described_class.call(rows: [{ service_id: service.id, bonus_sessions: "2" }], employee_id: employee.id)

    expect(result.created).to eq(1)
  end

  it "reports every row when the employee does not exist" do
    result = described_class.call(rows: [{ "service_id" => service.id, "paid_used" => "1" }], employee_id: 0)

    expect(result.created).to eq(0)
    expect(result.errors.sole).to start_with("Row 2: Validation failed")
  end
end
