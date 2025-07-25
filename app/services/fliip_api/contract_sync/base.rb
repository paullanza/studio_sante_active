module FliipApi
  module ContractSync
    # Base class for syncing contracts from the Fliip API into our local database.
    # Provides shared initialization, parsing helpers, and the core upsert logic.
    class Base
      def initialize(user)
        @user = user
        @api_client = FliipApi::ApiClient.new
      end

      # Insert or update a contract record based on its remote ID and associated user.
      def upsert_contract(data)
        attrs    = contract_attributes(data)
        contract = FliipContract.find_or_initialize_by(
          remote_contract_id: attrs[:remote_contract_id],
          fliip_user_id:      attrs[:fliip_user_id]
        )

        # Assign all fields and save only if anything changed (new or updated)
        contract.assign_attributes(attrs)
        contract.save! if contract.changed?
        contract
      end

      private

      # Helper to parse API dates
      def parse_date(value)
        Date.parse(value) rescue nil
      end

      # Build a normalized hash of attributes for mass-assignment.
      def contract_attributes(data)
        {
          remote_contract_id: data[:contract_id].to_i,
          fliip_user_id: @user.id,
          status: data[:status],
          start_date: parse_date(data[:start_date]),
          end_date: parse_date(data[:end_date]),
          stop_date: parse_date(data[:stop_date]),
          resume_date: parse_date(data[:resume_date]),
          cancel_date: parse_date(data[:cancel_date]),
          rebate: data[:rebate],
          discount_name: data[:discount_name],
          main_user_contract: data[:main_user_contract],
          membership_name: data[:membership_name],
          plan_base_type: data[:plan_base_type],
          plan_type: data[:plan_type],
          plan_description: data[:plan_description],
          plan_classes: data[:plan_classes],
          payment_terms: data[:payment_terms],
          duration: data[:duration],
          billed_at_purchase: data[:billed_at_purchase],
          ledger_account: data[:ledger_account],
          pack_class_num: data[:pack_class_num],
          pack_class_used: data[:pack_class_used]
        }
      end
    end
  end
end
