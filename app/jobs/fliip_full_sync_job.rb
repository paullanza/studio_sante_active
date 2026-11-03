# Nightly (and from the admin "import clients" button): every client and
# staff member in Fliip. Local users missing from both lists are checked one
# by one against their details: still there means synced, a 400 means
# flagged. If either list fails to load, the run stops before writing.
class FliipFullSyncJob < FliipSyncJob
  def perform
    rows = client.clients + client.staff
    summary = batch(rows)

    listed = rows.map { |row| row[:user_id].to_i }
    unlisted = FliipUser.present_in_fliip.where.not(remote_id: listed).order(:remote_id).pluck(:remote_id)
    finish(summary.merge(batch(unlisted)))
  end
end
