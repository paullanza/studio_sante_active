module FliipApi
  module UserSync
    # UserUpdater handles syncing a single local user record with data
    # fetched from the Fliip API.
    class UserUpdater < Base
      # Entry point: instantiate and run the update.
      # Accepts the local_user to sync.
      def self.call(*args, &block)
        new.update_local_user(*args, &block)
      end

      # Fetches the remote data for the given user and applies updates.
      def update_local_user(local_user)
        # Retrieve the latest API data for this user by their remote ID
        api_user = fetch_single_user(local_user.remote_id)
        # Assign attributes and save only if there are changes
        update_user(local_user, api_user)
      end
    end
  end
end
