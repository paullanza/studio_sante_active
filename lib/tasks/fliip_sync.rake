namespace :fliip do
  desc "Full Fliip sync, run inline (the nightly FliipFullSyncJob runs the same thing)"
  task sync: :environment do
    summary = FliipFullSyncJob.perform_now
    puts "[Fliip Sync] #{summary}"
    exit 0
  rescue => e
    warn "[Fliip Sync] FAILED: #{e.class}: #{e.message}"
    e.backtrace&.first(10)&.each { |line| warn line }
    exit 1
  end
end
