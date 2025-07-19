module FliipApi
  module UserSync
    # FullUpdater handles a full sync of users from the Fliip API into our local database
    class FullUpdater < Base
      # Entry point: builds a new instance, runs the sync, and returns a summary string
      def self.call
        counts = new.update_all_users
        "Sync complete: #{counts[0]} new users, #{counts[1]} updated users"
      end

      # Primary method: fetch data, compare with local, update or create records
      # Returns two integers: [number_of_new_users, number_of_updated_users]
      def update_all_users
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

        [new_users, updated_users]
      end

      private

      # Takes a local user and a hash of API data, assigns new values,
      # saves only if any attribute has changed, and returns true if saved
      def update_user(user, data)
        # Prepare normalized attributes from the incoming data
        attrs = user_attributes(data)
        # Assign attributes without saving yet
        user.assign_attributes(attrs)
        # Only hit the database if there are actual changes
        if user.changed?
          user.save!
          true
        else
          false
        end
      end
    end
  end
end
