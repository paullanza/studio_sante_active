namespace :fliip do
  desc "Daily sync of Fliip users → local DB"
  task sync: :environment do
    begin
      message = FliipApi::UserSync::UserImporter.call
      puts "[Fliip Sync] #{message}"
      exit 0
    rescue => e
      warn "[Fliip Sync] FAILED: #{e.class}: #{e.message}"
      e.backtrace&.first(10)&.each { |line| warn line }
      exit 1
    end
  end
end
