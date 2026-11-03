# Shared base for the scheduled Fliip syncs. They share one concurrency key,
# so they never run at the same time: a sync enqueued during another one
# waits its turn. A run with failed users raises at the end, so it shows as
# failed in Mission Control.
class FliipSyncJob < ApplicationJob
  queue_as :default
  limits_concurrency key: "fliip_sync", group: "FliipSync", duration: 2.hours

  private

  def client
    @client ||= FliipApi::Client.new
  end

  def syncer
    @syncer ||= FliipApi::UserSyncer.new(client: client)
  end

  def batch(items)
    FliipApi::BatchSync.new(syncer: syncer).call(items)
  end

  def finish(summary)
    Rails.logger.info("[Fliip] #{self.class.name}: #{summary}")
    raise FliipApi::PartialSync, "#{summary}: #{summary.failed.first(20).join('; ')}" if summary.failed.any?

    summary
  end
end
