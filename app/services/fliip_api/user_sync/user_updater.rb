module FliipApi
  module UserSync
    # UserUpdater handles syncing a single local user record with data
    # fetched from the Fliip API.
    class UserUpdater < Base
      # Entry point: instantiate and run the update.
      # Accepts the local_user to sync.
      def self.call(*args, &block)
        info = new.update_local_user(*args, &block)
        completion_message(info)
      end

      # Fetches the remote data for the given user and applies updates.
      # Branches on user_role to hit the correct API endpoint for staff vs. clients.
      def update_local_user(remote_id)
        start_time = Time.now
        local_user = FliipUser.find_by(remote_id: remote_id)
        api_user = if local_user&.staff?
                     @api_client.fetch_single_staff(remote_id)
                   else
                     @api_client.fetch_single_user(remote_id)
                   end
        upsert_user(api_user)

        end_time = Time.now

        {
          new_users: 0,
          updated_users: 1,
          start_time: start_time,
          end_time: end_time
        }
      end
    end
  end
end