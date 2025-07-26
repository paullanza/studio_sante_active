module FliipApi
  module UserSync
    class ServiceSync < Base
      # Base class for syncing services from the Fliip API into our local database.
      # Provides shared initialization, parsing helpers, and the core upsert logic.
      def initialize(user)
        @user = user
        @api_client = FliipApi::ApiClient.new
      end

      def self.call(*args, &block)
        new(*args, &block).call
      end

      # Fetches current, future, and historical services, and upserts each one
      def call
        sync_current
        sync_future
        sync_history
      end

      private

      # Insert or update a service record based on its remote ID and associated user.
      def upsert_service(data)
        attrs = service_attributes(data)
        service = FliipService.find_or_initialize_by(
          remote_purchase_id: attrs[:remote_purchase_id]
        )

        # Assign all fields and save only if anything changed (new or updated)
        service.assign_attributes(attrs)
        service.save! if service.changed?
        service
      end

      # 1) Sync current active services
      def sync_current
        @api_client.fetch_user_services(@user.remote_id).each do |data|
          upsert_service(data)
        end
      end

      # 2) Sync future services
      def sync_future
        @api_client.fetch_future_user_services(@user.remote_id).each do |data|
          upsert_service(data)
        end
      end

      # 3) Sync historical services
      def sync_history
        @api_client.fetch_history_user_services(@user.remote_id).each do |data|
          upsert_service(data)
        end
      end

      # Build a normalized hash of attributes for mass-assignment.
      def service_attributes(data)
        {
          remote_purchase_id: data[:service_purchase_id].to_i,
          fliip_user_id: @user.id,
          purchase_status: data[:purchase_status],
          start_date: parse_date(data[:start_date]),
          expire_date: parse_date(data[:expire_date]),
          purchase_date: parse_datetime(data[:purchase_date]),
          stop_date: parse_date(data[:stop_date]),
          cancel_date: parse_date(data[:cancel_date]),
          rebate: data[:rebate],
          stop_payments: data[:stop_payments] == '1',
          discount_name: data[:discount_name],
          service_id: data[:service_id].to_i,
          service_name: data[:service_name],
          service_type: data[:service_type],
          service_category_name: data[:service_category_name],
          coach: data[:coach],
          payment_terms: data[:payment_terms],
          duration: data[:duration],
          online_enabled: data[:online_enabled],
          service_description: data[:service_description],
          billed_at_purchase: data[:billed_at_purchase].to_i,
          ledger_account: data[:ledger_account]
        }
      end
    end
  end
end
