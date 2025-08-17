module CsvPorter
  module Importer
    class Adjustments
      # rows: Array<Hash> (string keys), each row from your preview payload
      # employee_id: Integer (the staff member the adjustments belong to)
      def self.call(rows:, employee_id:)
        created = 0
        errors  = []

        rows.each_with_index do |row, idx|
          begin
            service_id = fetch(row, "service_id")
            unless service_id.present?
              errors << "Row #{idx + 2}: service_id is missing"
              next
            end

            svc = FliipService.find_by(id: service_id.to_i)
            unless svc
              errors << "Row #{idx + 2}: FliipService ##{service_id} not found"
              next
            end

            paid_used  = to_f(fetch(row, "paid_used"))
            free_used  = to_f(fetch(row, "free_used"))
            bonus_sess = to_f(fetch(row, "bonus_sessions"))

            ServiceUsageAdjustment.create!(
              fliip_service_id: svc.id,
              user_id:          employee_id.to_i,
              paid_used_delta:  paid_used,
              free_used_delta:  free_used,
              bonus_sessions:   bonus_sess
            )

            created += 1
          rescue => e
            errors << "Row #{idx + 2}: #{e.message}"
          end
        end

        OpenStruct.new(success?: errors.empty?, created:, errors:)
      end

      # --- tiny helpers ---
      def self.fetch(row, key)
        row[key] || row[key.to_s] || row[key.to_sym]
      end

      def self.to_f(value)
        s = value.to_s.strip
        return 0.0 if s.empty?
        Float(s)
      rescue ArgumentError
        0.0
      end
    end
  end
end
