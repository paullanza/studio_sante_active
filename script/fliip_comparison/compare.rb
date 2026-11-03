# frozen_string_literal: true

# Read-only comparison of the local Fliip tables with the Fliip API.
#
#   bin/rails runner script/fliip_comparison/compare.rb
#   LIMIT=50 bin/rails runner script/fliip_comparison/compare.rb   # first 50 Fliip users only
#
# Writes report.md next to this script (gitignored). The report holds remote
# IDs, statuses, dates and service names only: no names, emails or phones.
#
# Safety:
# - The database session is set to READ ONLY first, so Postgres rejects any write.
# - It doesn't use FliipApi::ApiClient, which returns [] on any error and would
#   make a failed call look like a missing record. Failed calls are retried, then
#   the user is reported as "not checked".
# - Local records are loaded one Fliip user at a time to keep memory low.

require "httparty"
require "json"
require "set"

ActiveRecord::Base.connection.execute("SET SESSION CHARACTERISTICS AS TRANSACTION READ ONLY")

module FliipComparison
  REPORT_PATH = File.expand_path("report.md", __dir__)
  EXAMPLES = 10
  PAUSE = 0.05 # seconds between API calls
  MAX_CONSECUTIVE_FAILURES = 20

  # Fields shown with their values in examples. Every other field (names,
  # emails, phones, addresses, birthdays) is reported by count and ID only.
  SAFE_FIELDS = %w[
    user_role user_status member_type member_since
    status purchase_status start_date end_date expire_date purchase_date stop_date
    resume_date cancel_date service_id service_name service_type service_category_name
    membership_name plan_type plan_base_type duration payment_terms stop_payments
    billed_at_purchase online_enabled pack_class_num pack_class_used
  ].to_set.freeze

  class NotFound < StandardError; end
  class FetchError < StandardError; end

  # Minimal read-only client with timeouts, retries and explicit errors.
  class Client
    BASE = "https://static.fliipapp.com/api/v2"
    attr_reader :calls

    def initialize
      @headers = { "Authorization" => ENV.fetch("FLIIP_API_KEY") }
      @calls = 0
    end

    # Returns the parsed array. Raises NotFound on 400 (unknown user id),
    # FetchError when retries run out.
    def get(path)
      attempts = 0
      begin
        attempts += 1
        @calls += 1
        sleep PAUSE
        response = HTTParty.get(BASE + path, headers: @headers, timeout: 30)
        raise NotFound, path if response.code == 400
        raise FetchError, "#{response.code} on #{path}" unless response.code == 200

        parsed = JSON.parse(response.body.to_s.dup.force_encoding(Encoding::UTF_8).scrub)
        raise FetchError, "unexpected #{parsed.class} on #{path}" unless parsed.is_a?(Array) || parsed.is_a?(Hash)

        parsed
      rescue FetchError, JSON::ParserError, Timeout::Error, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        raise FetchError, "#{e.class}: #{e.message}" if attempts >= 3

        sleep 2**attempts
        retry
      end
    end

    def paged(path)
      rows = []
      offset = 0
      loop do
        page = get("#{path}?limit=100&offset=#{offset}")
        rows.concat(page)
        break if page.size < 100

        offset += 100
      end
      rows
    end
  end

  # Collects examples and counts for the report.
  class Bucket
    attr_reader :count, :examples

    def initialize
      @count = 0
      @examples = []
    end

    def add(example)
      @count += 1
      @examples << example if @examples.size < EXAMPLES
    end
  end

  class Run
    def initialize
      @client = Client.new
      @limit = ENV["LIMIT"]&.to_i
      @started = Time.current
      @b = Hash.new { |h, k| h[k] = Bucket.new }
      @field_diffs = Hash.new { |h, k| h[k] = Hash.new { |hh, f| hh[f] = Bucket.new } }
      @endpoint_disagreements = Hash.new { |h, k| h[k] = Hash.new { |hh, f| hh[f] = Bucket.new } }
      @seen_services = {} # remote_purchase_id => fliip remote user id
      @seen_contracts = {}
      @checked_users = Set.new
      @unchecked_users = Set.new
      @fliip_service_ids = Set.new
      @notes = []
      @complete = false
    end

    def call
      load_local_index
      fetch_user_lists
      compare_users
      walk_users
      local_only_records
      definitions
      @complete = true
    rescue Interrupt
      @notes << "Interrupted by the user."
    rescue => e
      @notes << "Aborted: #{e.class}: #{e.message}"
      raise
    ensure
      write_report
    end

    private

    # --- Local data (IDs only) ---------------------------------------------

    def load_local_index
      @local_users = FliipUser.pluck(:remote_id, :id, :user_role).to_h { |r, id, role| [r, { id: id, role: role }] }
      @local_user_remote_by_id = @local_users.to_h { |r, v| [v[:id], r] }
      @local_services = FliipService.pluck(:remote_purchase_id, :fliip_user_id, :purchase_status).to_h { |r, u, s| [r, { owner: u, status: s }] }
      @local_contracts = FliipContract.pluck(:remote_contract_id, :fliip_user_id, :status).to_h { |r, u, s| [r, { owner: u, status: s }] }

      duplicates(FliipUser, :remote_id, :dup_users)
      duplicates(FliipService, :remote_purchase_id, :dup_services)
      duplicates(FliipContract, :remote_contract_id, :dup_contracts)
    end

    def duplicates(model, column, key)
      model.where(column => nil).pluck(:id).each { |id| @b[:"#{key}_nil"].add("local id #{id}") }
      model.group(column).having("COUNT(*) > 1").count.each do |remote, n|
        next if remote.nil?

        @b[key].add("#{remote} (#{n} rows)")
      end
    end

    # --- Users -------------------------------------------------------------

    def fetch_user_lists
      log "Fetching the Fliip user and staff lists…"
      @fliip_clients = @client.paged("/users/get")
      @fliip_staff = @client.get("/staff/get")
      @fliip_users = {}
      @fliip_clients.each { |u| @fliip_users[u["user_id"].to_i] = u }
      @fliip_staff.each do |u|
        id = u["user_id"].to_i
        @b[:in_both_lists].add(id.to_s) if @fliip_users.key?(id)
        @fliip_users[id] = u
      end
    end

    def compare_users
      builder = FliipApi::UserSync::Base.allocate
      fliip_ids = @fliip_users.keys.to_set
      local_ids = @local_users.keys.compact.to_set

      (fliip_ids - local_ids).each { |id| @b[:users_fliip_only].add("#{id} (#{@fliip_users[id]["user_role"]}, #{@fliip_users[id]["user_status"]})") }

      # Users gone from both lists: ask /users/details directly (staff details for staff).
      (local_ids - fliip_ids).each do |id|
        role = @local_users[id][:role]
        endpoint = role.present? && role != "user" ? "/staff/details/#{id}" : "/users/details/#{id}"
        verdict = begin
          @client.get(endpoint)
          "details still returns it"
        rescue NotFound
          "details returns 400"
        rescue FetchError => e
          "details failed (#{e.message})"
        end
        @b[:users_local_only].add("#{id} (#{role}): #{verdict}")
        @b[:"users_local_only_#{verdict.split(" (").first.parameterize(separator: "_")}"].add(id.to_s)
      end

      (fliip_ids & local_ids).each_slice(500) do |slice|
        FliipUser.where(remote_id: slice).find_each do |user|
          attrs = builder.send(:user_attributes, @fliip_users[user.remote_id].deep_symbolize_keys)
          record_diffs(:users, user, attrs, user.remote_id)
        end
      end
    end

    # --- Services and contracts, one Fliip user at a time -----------------

    def walk_users
      ids = @fliip_users.keys.sort
      ids = ids.first(@limit) if @limit&.positive?
      @notes << "LIMIT=#{@limit}: only #{ids.size} of #{@fliip_users.size} Fliip users were walked." if @limit&.positive?
      failures = 0

      ids.each_with_index do |remote_id, i|
        progress(i, ids.size) if (i % 100).zero?
        begin
          services = fetch_merged(remote_id, "services", "service_purchase_id")
          contracts = fetch_merged(remote_id, "contracts", "contract_id")
          failures = 0
        rescue NotFound
          @b[:list_user_400].add(remote_id.to_s)
          @unchecked_users << remote_id
          next
        rescue FetchError => e
          failures += 1
          @unchecked_users << remote_id
          @b[:fetch_failures].add("#{remote_id}: #{e.message}")
          raise "#{failures} users in a row failed to fetch; the API looks down" if failures >= MAX_CONSECUTIVE_FAILURES

          next
        end

        @checked_users << remote_id
        owner = @local_users[remote_id] && FliipUser.find(@local_users[remote_id][:id])
        compare_services(owner, remote_id, services)
        compare_contracts(owner, remote_id, contracts)
      end
      progress(ids.size, ids.size)
    end

    # Merges current, future and history in the sync's order; the last
    # endpoint wins, like the sync. When endpoints return the same record with
    # different stored values, the difference is counted.
    def fetch_merged(remote_id, kind, id_key)
      merged = {}
      %w[get get_future get_history].each do |endpoint|
        @client.get("/#{kind}/#{endpoint}/#{remote_id}").each do |row|
          rid = row[id_key].to_i
          if merged.key?(rid)
            before = stored_attributes(kind, merged[rid][:row])
            after = stored_attributes(kind, row)
            before.each do |f, value|
              next if value == after[f]

              @endpoint_disagreements[kind][f.to_s].add("#{rid}: #{merged[rid][:endpoint]}=#{show(f, value)} #{endpoint}=#{show(f, after[f])}")
            end
          end
          merged[rid] = { row: row, endpoint: endpoint }
        end
      end
      merged.transform_values { |v| v[:row] }
    end

    NO_OWNER = Struct.new(:id).new(nil)

    # The attributes the sync would store for a row, without the owner.
    def stored_attributes(kind, row)
      klass, method = kind == "services" ? [FliipApi::UserSync::ServiceSync, :service_attributes] : [FliipApi::UserSync::ContractSync, :contract_attributes]
      builder = klass.allocate
      builder.instance_variable_set(:@user, NO_OWNER)
      builder.send(method, row.deep_symbolize_keys).except(:fliip_user_id)
    end

    def compare_services(owner, remote_id, rows)
      builder = FliipApi::UserSync::ServiceSync.allocate
      builder.instance_variable_set(:@user, owner)
      locals = FliipService.where(remote_purchase_id: rows.keys).index_by(&:remote_purchase_id)

      rows.each do |rid, row|
        @seen_services[rid] = remote_id
        @fliip_service_ids << row["service_id"].to_i
        local = locals[rid]
        next @b[:services_fliip_only].add("#{rid} (user #{remote_id}, #{row["purchase_status"]}, #{row["service_name"]})") unless local
        next @b[:services_moved].add("#{rid}: local owner #{@local_user_remote_by_id[local.fliip_user_id]}, Fliip owner #{remote_id}") if owner.nil? || local.fliip_user_id != owner.id

        record_diffs(:services, local, builder.send(:service_attributes, row.deep_symbolize_keys), rid)
      end
    end

    def compare_contracts(owner, remote_id, rows)
      builder = FliipApi::UserSync::ContractSync.allocate
      builder.instance_variable_set(:@user, owner)
      locals = FliipContract.where(remote_contract_id: rows.keys).index_by(&:remote_contract_id)

      rows.each do |rid, row|
        @seen_contracts[rid] = remote_id
        local = locals[rid]
        next @b[:contracts_fliip_only].add("#{rid} (user #{remote_id}, #{row["status"]})") unless local
        next @b[:contracts_moved].add("#{rid}: local owner #{@local_user_remote_by_id[local.fliip_user_id]}, Fliip owner #{remote_id}") if owner.nil? || local.fliip_user_id != owner.id

        record_diffs(:contracts, local, builder.send(:contract_attributes, row.deep_symbolize_keys), rid)
      end
    end

    # Assigns the attributes the sync would write, in memory only, and records
    # what would change. Nothing is saved (and the session is read-only).
    def record_diffs(table, record, attrs, rid)
      record.assign_attributes(attrs.except(:fliip_user_id))
      record.changes.each do |field, (from, to)|
        @field_diffs[table][field].add(SAFE_FIELDS.include?(field) ? "#{rid}: #{show(field, from)} → #{show(field, to)}" : rid.to_s)
      end
      @b[:"#{table}_with_diffs"].add(rid.to_s) if record.changed?
      record.restore_attributes
    end

    # --- Local records Fliip no longer returns ------------------------------

    def local_only_records
      walked_complete = !@limit&.positive?
      [[:services, @local_services, @seen_services], [:contracts, @local_contracts, @seen_contracts]].each do |table, locals, seen|
        gone = []
        locals.each do |rid, info|
          next if rid.nil? || seen.key?(rid)

          owner_remote = @local_user_remote_by_id[info[:owner]]
          if @checked_users.include?(owner_remote) || (walked_complete && !@fliip_users.key?(owner_remote) && !@unchecked_users.include?(owner_remote))
            gone << rid
            @b[:"#{table}_local_only"].add("#{rid} (user #{owner_remote}, #{info[:status]})")
          else
            @b[:"#{table}_not_checked"].add(rid.to_s)
          end
        end
        @gone_status = (@gone_status || {}).merge(table => gone.map { |rid| locals[rid][:status] }.tally)
        next unless table == :services

        ids = FliipService.where(remote_purchase_id: gone).pluck(:id)
        @gone_usage = {
          sessions: Session.where(fliip_service_id: ids).count,
          confirmed_sessions: Session.where(fliip_service_id: ids, confirmed: true).count,
          services_with_sessions: Session.where(fliip_service_id: ids).distinct.count(:fliip_service_id),
          consultations: Consultation.where(fliip_service_id: ids).count,
          adjustments: ServiceUsageAdjustment.where(fliip_service_id: ids).count
        }
      end
    end

    def definitions
      defined = ServiceDefinition.pluck(:service_id).to_set
      FliipService.distinct.pluck(:service_id).each { |sid| @b[:local_service_ids_without_definition].add(sid.to_s) unless defined.include?(sid) }
      @fliip_service_ids.each { |sid| @b[:fliip_service_ids_without_definition].add(sid.to_s) unless defined.include?(sid) }
      ServiceDefinition.group(:service_id).having("COUNT(*) > 1").count.each { |sid, n| @b[:dup_definitions].add("#{sid} (#{n} rows)") }
    end

    # --- Output --------------------------------------------------------------

    def show(field, value)
      return "[hidden]" unless SAFE_FIELDS.include?(field.to_s)

      value.nil? ? "nil" : value.inspect
    end

    def log(msg)
      warn "[compare] #{msg}"
    end

    def progress(done, total)
      elapsed = Time.current - @started
      eta = done.positive? ? ((elapsed / done) * (total - done) / 60).round : "?"
      log "#{done}/#{total} users walked, #{@client.calls} API calls, ~#{eta} min left, RSS #{rss_mb} MB"
    end

    def rss_mb
      File.read("/proc/self/status")[/VmRSS:\s+(\d+)/, 1].to_i / 1024
    rescue StandardError
      "?"
    end

    def section(title, key, why = nil)
      bucket = @b[key]
      out = +"### #{title}: #{bucket.count}\n"
      out << "#{why}\n" if why
      out << bucket.examples.map { |e| "- #{e}" }.join("\n") << "\n" if bucket.examples.any?
      out << "- … and #{bucket.count - bucket.examples.size} more\n" if bucket.count > bucket.examples.size
      out << "\n"
    end

    def diff_table(diffs)
      return "None.\n\n" if diffs.empty?

      diffs.sort_by { |_, bk| -bk.count }.map do |field, bk|
        "- **#{field}**: #{bk.count}\n" + bk.examples.first(5).map { |e| "  - #{e}" }.join("\n")
      end.join("\n") + "\n\n"
    end

    def write_report
      r = +"# Fliip comparison report\n\n"
      r << "**INCOMPLETE.** #{@notes.join(" ")}\n\n" unless @complete
      r << "Run #{@started.iso8601} → #{Time.current.iso8601} (#{((Time.current - @started) / 60).round(1)} min), #{@client.calls} API calls, peak RSS about #{rss_mb} MB, env #{Rails.env}.\n"
      r << "Local: #{@local_users&.size} users, #{@local_services&.size} services, #{@local_contracts&.size} contracts. "
      r << "Fliip: #{@fliip_clients&.size} clients + #{@fliip_staff&.size} staff. Walked #{@checked_users.size} users, #{@unchecked_users.size} not checked.\n"
      r << "Latest local updated_at: users #{FliipUser.maximum(:updated_at)}, services #{FliipService.maximum(:updated_at)}, contracts #{FliipContract.maximum(:updated_at)}.\n\n"
      @notes.each { |n| r << "> #{n}\n" } if @complete && @notes.any?

      r << "## Duplicate and missing remote IDs\n\n"
      r << section("Duplicate users.remote_id", :dup_users)
      r << section("Users with no remote_id", :dup_users_nil)
      r << section("Duplicate services.remote_purchase_id", :dup_services)
      r << section("Services with no remote_purchase_id", :dup_services_nil)
      r << section("Duplicate contracts.remote_contract_id", :dup_contracts)
      r << section("Contracts with no remote_contract_id", :dup_contracts_nil)
      r << section("Duplicate service_definitions.service_id", :dup_definitions)

      r << "## Users\n\n"
      r << section("In Fliip, not local", :users_fliip_only, "New since the last sync, or never synced.")
      r << section("Local, not in the Fliip lists", :users_local_only, "Checked one by one against the details endpoint.")
      r << section("…of which details still returns them", :users_local_only_details_still_returns_it, "Exist in Fliip but /users/get and /staff/get no longer list them.")
      r << section("…of which details returns 400", :users_local_only_details_returns_400, "Gone from Fliip.")
      r << section("In both the client and staff lists", :in_both_lists)
      r << section("Listed by /users/get but per-user calls return 400", :list_user_400)
      r << section("Users whose stored fields differ", :users_with_diffs)
      r << "Fields that differ (what a sync would change now):\n\n" << diff_table(@field_diffs[:users])

      r << "## Services\n\n"
      r << section("In Fliip, not local", :services_fliip_only)
      r << section("Local, not returned by Fliip", :services_local_only, "Owner was walked (or is gone from Fliip) and no endpoint returned the service.")
      r << "Statuses of those: #{@gone_status&.dig(:services).inspect}\n\n"
      r << "History attached to them: #{@gone_usage.inspect}\n\n" if @gone_usage
      r << section("Local but owner not checked", :services_not_checked)
      r << section("Owner differs (local vs Fliip)", :services_moved)
      r << section("Services whose stored fields differ", :services_with_diffs)
      r << "Fields that differ (what a sync would change now):\n\n" << diff_table(@field_diffs[:services])
      r << "Same service returned by several endpoints with different content (the sync keeps the last one: get → get_future → get_history):\n\n"
      r << diff_table(@endpoint_disagreements["services"])

      r << "## Contracts\n\n"
      r << section("In Fliip, not local", :contracts_fliip_only)
      r << section("Local, not returned by Fliip", :contracts_local_only)
      r << "Statuses of those: #{@gone_status&.dig(:contracts).inspect}\n\n"
      r << section("Local but owner not checked", :contracts_not_checked)
      r << section("Owner differs (local vs Fliip)", :contracts_moved)
      r << section("Contracts whose stored fields differ", :contracts_with_diffs)
      r << "Fields that differ (what a sync would change now):\n\n" << diff_table(@field_diffs[:contracts])
      r << "Same contract returned by several endpoints with different content:\n\n"
      r << diff_table(@endpoint_disagreements["contracts"])

      r << "## Service definitions\n\n"
      r << section("Local service_ids with no definition", :local_service_ids_without_definition)
      r << section("Fliip service_ids with no definition", :fliip_service_ids_without_definition)

      r << "## API failures\n\n"
      r << section("Users whose calls failed after retries", :fetch_failures)

      File.write(REPORT_PATH, r)
      log "Report written to #{REPORT_PATH}"
    end
  end
end

FliipComparison::Run.new.call
