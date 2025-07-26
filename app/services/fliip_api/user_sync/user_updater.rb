module FliipApi
  module UserSync
    # UserUpdater handles syncing a single local user record with data
    # fetched from the Fliip API.
    class UserUpdater < Base
      # Entry point: instantiate and run the update.
      # Accepts the local_user to sync.
      def self.call(*args, &block)
        counts = new.update_local_user(*args, &block)
        completion_message(counts)
      end

      # Fetches the remote data for the given user and applies updates.
      def update_local_user(user)
        # Retrieve the latest API data for this user by their remote ID
        api_user = @api_client.fetch_single_user(user.remote_id)
        # Assign attributes and save only if there are changes
        upsert_user(api_user)
      end
    end
  end
end
