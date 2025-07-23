module FliipApi
  module UserSync
    # UserImporter handles a full sync of users from the Fliip API into our local database
    class UserImporter < Base
      # Entry point: builds a new instance, runs the sync, and returns a summary string
      def self.call
        counts = new.create_or_update_all_users
        "Sync complete: #{counts[0]} new users, #{counts[1]} updated users."
      end

      # Primary method: fetch data, compare with local, update or create records
      # Returns two integers: [number_of_new_users, number_of_updated_users]
      def create_or_update_all_users
        new_users = 0
        updated_users = 0

        # 1. Pull all user data from the remote API
        api_data = fetch_all_api_users
        # 2. Load existing users into a hash for quick lookup (defined in Base)
        existing_users = load_local_users

        # 3. Iterate over each remote record
        api_data.each do |data|
          # Convert API user ID to integer for consistent key lookup
          remote_id = data[:user_id].to_i

          if existing_users[remote_id]
            # If we already have this user locally, update only if changed
            user = existing_users[remote_id]
            updated_users += 1 if update_user(user, data)
          else
            # If user doesn't exist locally, create a new record
            create_user(data)
            new_users += 1
          end
        end
        # Return the number of new users and changed users as an array to display when called.
        [new_users, updated_users]
      end

      private

      # Loads all FliipUser records from the database, keyed by remote_id
      # This allows O(1) lookup when syncing large datasets
      def load_local_users
        FliipUser.all.index_by(&:remote_id)
      end

      # Delegates to the API client to fetch all users from Fliip's service
      # Abstracted here to keep external HTTP logic out of the sync loop
      def fetch_all_api_users
        @api_client.fetch_all_users
      end
    end
  end
end
