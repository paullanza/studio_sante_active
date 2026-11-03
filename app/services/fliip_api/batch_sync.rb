module FliipApi
  # Runs the per-user sync over many users and keeps going when one fails.
  # Items are API rows (from the user lists) or remote ids (synced from
  # their details). Nothing of a failed user is flagged. Too many failures
  # in a row means Fliip is down, and the run stops.
  class BatchSync
    MAX_CONSECUTIVE_FAILURES = 20

    Summary = Struct.new(:synced, :changed, :not_found, :failed) do
      def self.empty
        new(0, 0, [], [])
      end

      def merge(other)
        Summary.new(synced + other.synced, changed + other.changed, not_found + other.not_found, failed + other.failed)
      end

      def to_s
        "#{synced} synced (#{changed} changed), #{not_found.size} not found in Fliip, #{failed.size} failed"
      end
    end

    def initialize(syncer:)
      @syncer = syncer
    end

    def call(items)
      summary = Summary.empty
      consecutive_failures = 0

      items.each do |item|
        remote_id = item.is_a?(Hash) ? item[:user_id].to_i : item.to_i
        begin
          result = item.is_a?(Hash) ? @syncer.call(item) : @syncer.call_by_remote_id(item)
          summary.synced += 1
          summary.changed += 1 if result.changed?
          consecutive_failures = 0
        rescue NotFound
          # Fliip answered: it no longer knows this user, who is now flagged.
          summary.not_found << remote_id
          consecutive_failures = 0
        rescue StandardError => e
          summary.failed << "#{remote_id}: #{e.class}: #{e.message}"
          consecutive_failures += 1
          Rails.logger.error("[Fliip] user #{remote_id} failed: #{e.class}: #{e.message}")
          if consecutive_failures >= MAX_CONSECUTIVE_FAILURES
            raise Unavailable, "stopped after #{MAX_CONSECUTIVE_FAILURES} failures in a row (#{summary})"
          end
        end
      end

      summary
    end
  end
end
