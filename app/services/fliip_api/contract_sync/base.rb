module FliipApi
  module ContractSync
    # Shared setup & helpers for all contract syncers
    class Base
      def initialize(user)
        @user       = user
        @api_client = FliipApi::ApiClient.new
      end

      private

      # Helper to parse API dates
      def parse_date(val)
        Date.parse(val) rescue nil
      end

      # Upsert a single contract payload
      def upsert_contract(data)
        attrs = {
          remote_contract_id: data["contract_id"].to_i,
          fliip_user_id:      @user.id,
          status:             data["status"],
          start_date:         parse_date(data["start_date"]),
          end_date:           parse_date(data["end_date"]),
          # …etc for all your fields…
        }
        contract = FliipContract.find_or_initialize_by(remote_contract_id: attrs[:remote_contract_id])
        contract.assign_attributes(attrs)
        contract.save! if contract.changed?
      end
    end
  end
end
