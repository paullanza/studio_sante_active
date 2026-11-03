# Hourly: new clients, plus the owners of services or contracts that ended
# in the last 30 days (the clients most likely to have just bought again).
class FliipRecentSyncJob < FliipSyncJob
  WINDOW = 30.days

  def perform
    summary = FliipApi::NewClients.new(client: client, syncer: syncer).call
    finish(summary.merge(batch(recent_remote_ids)))
  end

  private

  def recent_remote_ids
    range = (Date.current - WINDOW)..Date.current
    FliipUser.where(id: FliipService.where(expire_date: range).select(:fliip_user_id))
             .or(FliipUser.where(id: FliipContract.where(end_date: range).select(:fliip_user_id)))
             .order(:remote_id).pluck(:remote_id)
  end
end
