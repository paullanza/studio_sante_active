module FliipApi
  # Brings one Fliip user (client or staff) fully up to date: the user, all
  # their services and all their contracts. Every sync entry point uses it.
  #
  #   syncer = FliipApi::UserSyncer.new(client: FliipApi::Client.new)
  #   syncer.call(row)                  # a row from /users/get or /staff/get
  #   syncer.call_by_remote_id(123)     # fetches the user's details first
  #
  # Everything is fetched before anything is written, so an Unavailable
  # changes nothing. A NotFound flags the user and their records (Fliip no
  # longer knows them), then re-raises so the caller can say so.
  class UserSyncer
    Result = Struct.new(:user, :user_change, :services, :contracts, :definitions_created, keyword_init: true) do
      def changed?
        user_change != :unchanged || services.values_at(:created, :updated, :flagged).sum.positive? ||
          contracts.values_at(:created, :updated, :flagged).sum.positive?
      end
    end

    def initialize(client:)
      @client = client
    end

    def call(row)
      remote_id = Integer(row.fetch(:user_id))
      services = @client.services(remote_id)
      contracts = @client.contracts(remote_id)
      write(row, services, contracts)
    rescue NotFound
      flag_user!(remote_id)
      raise
    end

    # For a single refresh: staff details for known staff, client details
    # otherwise, falling back to staff details for an unknown id.
    def call_by_remote_id(remote_id)
      remote_id = Integer(remote_id)
      call(details_for(remote_id))
    rescue NotFound
      flag_user!(remote_id)
      raise
    end

    private

    def details_for(remote_id)
      local = FliipUser.find_by(remote_id: remote_id)
      return @client.staff_member(remote_id) if local&.staff?

      begin
        @client.client(remote_id)
      rescue NotFound
        raise if local
        @client.staff_member(remote_id)
      end
    end

    def write(row, service_rows, contract_rows)
      attempts = 0
      begin
        attempts += 1
        ActiveRecord::Base.transaction do
          user, user_change = upsert_user(row)
          services, service_counts = upsert_owned(FliipService, :remote_purchase_id, service_rows.map { |r| Mapper.service(r) }, user)
          _, contract_counts = upsert_owned(FliipContract, :remote_contract_id, contract_rows.map { |r| Mapper.contract(r) }, user)
          definitions = ServiceDefinition.ensure_for!(services)

          Result.new(user: user, user_change: user_change, services: service_counts,
                     contracts: contract_counts, definitions_created: definitions)
        end
      rescue ActiveRecord::RecordNotUnique
        # Another sync inserted the same remote id between our read and write.
        retry if attempts == 1
        raise
      end
    end

    def upsert_user(row)
      user = FliipUser.find_or_initialize_by(remote_id: Integer(row.fetch(:user_id)))
      change = user.new_record? ? :created : :updated
      user.assign_attributes(Mapper.user(row).merge(missing_from_fliip_at: nil))
      return [ user, :unchanged ] unless user.changed?

      user.save!
      [ user, change ]
    end

    # Upserts the records Fliip returned for this user (taking over any that
    # were stored under someone else), flags this user's records Fliip didn't
    # return, and clears the flag on the ones it did.
    def upsert_owned(model, key, rows, user)
      counts = { created: 0, updated: 0, unchanged: 0, flagged: 0 }
      existing = model.where(key => rows.map { |r| r[key] }).index_by(&key)

      records = rows.map do |attrs|
        record = existing[attrs[key]] || model.new
        new_record = record.new_record?
        record.assign_attributes(attrs.merge(fliip_user_id: user.id, missing_from_fliip_at: nil))
        if record.changed?
          record.save!
          counts[new_record ? :created : :updated] += 1
        else
          counts[:unchanged] += 1
        end
        record
      end

      now = Time.current
      counts[:flagged] = model.where(fliip_user_id: user.id).present_in_fliip
                              .where.not(key => rows.map { |r| r[key] })
                              .update_all(missing_from_fliip_at: now, updated_at: now)
      [ records, counts ]
    end

    # Fliip doesn't know this user any more: flag them and everything of theirs.
    def flag_user!(remote_id)
      user = FliipUser.find_by(remote_id: remote_id)
      return unless user

      now = Time.current
      ActiveRecord::Base.transaction do
        user.update!(missing_from_fliip_at: now) unless user.missing_from_fliip?
        [ FliipService, FliipContract ].each do |model|
          model.where(fliip_user_id: user.id).present_in_fliip.update_all(missing_from_fliip_at: now, updated_at: now)
        end
      end
    end
  end
end
