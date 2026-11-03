require "rails_helper"

RSpec.describe FliipApi::Mapper do
  def example(name)
    rows = JSON.parse(Rails.root.join("docs/fliip_api/examples/#{name}.json").read)
    (rows.is_a?(Array) ? rows.first : rows).deep_symbolize_keys
  end

  describe ".user" do
    it "maps a users/get row onto the fliip_users columns" do
      attrs = described_class.user(example("users_get"))

      expect(attrs).to include(remote_id: 26_605, user_role: "member",
                               user_dob: Date.new(1982, 11, 27), member_since: Date.new(2024, 4, 12))
      expect(attrs.keys - FliipUser.column_names.map(&:to_sym)).to be_empty
    end

    it "leaves out keys the row doesn't have, so they aren't blanked" do
      attrs = described_class.user({ user_id: "5", user_firstname: "Ana" })

      expect(attrs).to eq(remote_id: 5, user_firstname: "Ana")
    end

    it "turns invalid dates into nil" do
      expect(described_class.user({ user_id: "5", user_dob: "0000-00-00" })[:user_dob]).to be_nil
    end

    it "raises on a row without a user id" do
      expect { described_class.user({ user_firstname: "Ana" }) }.to raise_error(KeyError)
    end
  end

  describe ".service" do
    it "maps a services row onto the fliip_services columns" do
      attrs = described_class.service(example("services_get"))

      expect(attrs).to include(remote_purchase_id: 857, purchase_status: "A", service_id: 444,
                               stop_payments: false, billed_at_purchase: 1, online_enabled: "1",
                               expire_date: Date.new(2022, 8, 23))
      expect(attrs.keys - FliipService.column_names.map(&:to_sym)).to be_empty
    end

    it "reads the zoneless purchase_date as UTC" do
      attrs = described_class.service(example("services_get"))

      expect(attrs[:purchase_date]).to eq(Time.utc(2021, 8, 23, 8, 34, 54))
    end

    it "reads stop_payments '1' as true" do
      expect(described_class.service(example("services_get").merge(stop_payments: "1"))[:stop_payments]).to be(true)
    end

    it "accepts a null expire date" do
      expect(described_class.service(example("services_get").merge(expire_date: nil))[:expire_date]).to be_nil
    end
  end

  describe ".contract" do
    it "maps a contracts row onto the fliip_contracts columns" do
      attrs = described_class.contract(example("contracts_get"))

      expect(attrs).to include(remote_contract_id: 1234, status: "A", billed_at_purchase: "1",
                               start_date: Date.new(2026, 1, 15), end_date: Date.new(2026, 12, 31))
      expect(attrs.keys - FliipContract.column_names.map(&:to_sym)).to be_empty
    end
  end
end
