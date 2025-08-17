module CsvPorter
  module Exporter
    class Services < Base
      HEADERS = %w[
        client_id
        client_remote_id
        client_name
        service_id
        service_remote_purchase_id
        service_name
        purchase_status
        start_date
        expire_date
        paid_used
        paid_included
        free_used
        free_included
        bonus_sessions
      ].freeze

      def self.call
        new.call
      end

      def call
        services = FliipService
          .includes(:fliip_user, :service_definition)
          .order(:fliip_user_id, :service_name)

        service_ids = services.map(&:id)

        # session usage (sum of duration) by service + type
        session_sums = Session
          .where(fliip_service_id: service_ids)
          .group(:fliip_service_id, :session_type)
          .sum(:duration) # { [id, "paid"]=>x, [id, "free"]=>y }

        # adjustments
        adj_paid  = ServiceUsageAdjustment.where(fliip_service_id: service_ids).group(:fliip_service_id).sum(:paid_used_delta)
        adj_free  = ServiceUsageAdjustment.where(fliip_service_id: service_ids).group(:fliip_service_id).sum(:free_used_delta)
        bonus_sum = ServiceUsageAdjustment.where(fliip_service_id: service_ids).group(:fliip_service_id).sum(:bonus_sessions)

        csv_str = csv_generate(HEADERS) do |csv|
          services.each do |svc|
            user = svc.fliip_user
            defn = svc.service_definition

            paid_used = session_sums.fetch([svc.id, "paid"], 0.0).to_f + adj_paid.fetch(svc.id, 0.0).to_f
            free_used = session_sums.fetch([svc.id, "free"], 0.0).to_f + adj_free.fetch(svc.id, 0.0).to_f
            bonus     = bonus_sum.fetch(svc.id, 0.0).to_f

            csv << [
              user&.id,
              user&.remote_id,
              [user&.user_firstname, user&.user_lastname].compact.join(" "),
              svc.id,
              svc.remote_purchase_id,
              svc.service_name,
              svc.purchase_status, # "A"/"I"/"P"/"C"/"S"
              csv_safe_date(svc.start_date),
              csv_safe_date(svc.expire_date),
              paid_used,
              defn&.paid_sessions,
              free_used,
              defn&.free_sessions,
              bonus
            ]
          end
        end

        filename = "clients_services_#{Time.current.strftime('%Y%m%d-%H%M%S')}.csv"
        [csv_str, filename]
      end
    end
  end
end
