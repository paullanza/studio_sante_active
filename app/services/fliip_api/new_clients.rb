module FliipApi
  # Syncs users Fliip has and the app doesn't yet: clients newer than the
  # newest local client (Fliip lists clients newest first, so this usually
  # reads one page), plus staff not stored yet (staff ids aren't ordered).
  class NewClients
    def initialize(client:, syncer: UserSyncer.new(client: client))
      @client = client
      @syncer = syncer
    end

    def call
      BatchSync.new(syncer: @syncer).call(new_client_rows + new_staff_rows)
    end

    private

    def new_client_rows
      newest = FliipUser.where(user_role: "user").maximum(:remote_id)
      rows = []
      @client.client_pages.each do |page|
        fresh = newest ? page.select { |row| row[:user_id].to_i > newest } : page
        rows.concat(fresh)
        break if newest && fresh.size < page.size
      end
      rows
    end

    def new_staff_rows
      staff = @client.staff
      known = FliipUser.where(remote_id: staff.map { |row| row[:user_id].to_i }).pluck(:remote_id).to_set
      staff.reject { |row| known.include?(row[:user_id].to_i) }
    end
  end
end
