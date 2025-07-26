module FliipApi
  module UserSync
    class ContractSync < Base
      # Base class for syncing contracts from the Fliip API into our local database.
      # Provides shared initialization, parsing helpers, and the core upsert logic.
      def initialize(user)
        @user = user
        @api_client = FliipApi::ApiClient.new
      end

      def self.call(*args, &block)
        new(*args, &block).call
      end

      # Fetches current, future, and historical contracts, and upserts each one
      def call
        sync_current
        sync_future
        sync_history
      end

      private

      # Insert or update a contract record based on its remote ID and associated user.
      def upsert_contract(data)
        attrs = contract_attributes(data)
        contract = FliipContract.find_or_initialize_by(
          remote_contract_id: attrs[:remote_contract_id]
        )

        # Assign all fields and save only if anything changed (new or updated)
        contract.assign_attributes(attrs)
        contract.save! if contract.changed?
        contract
      end

      # 1) Sync current active contracts
      def sync_current
        @api_client.fetch_user_contracts(@user.remote_id).each do |data|
          upsert_contract(data)
        end
      end

      # 2) Sync future contracts
      def sync_future
        @api_client.fetch_future_user_contracts(@user.remote_id).each do |data|
          upsert_contract(data)
        end
      end

      # 3) Sync historical contracts
      def sync_history
        @api_client.fetch_history_user_contracts(@user.remote_id).each do |data|
          upsert_contract(data)
        end
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
