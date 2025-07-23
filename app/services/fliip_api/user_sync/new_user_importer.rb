module FliipApi
  module UserSync
    # NewUserImporter imports users created after the last sync from the Fliip API
    class NewUserImporter < Base
      # Entry point: calls create_new_users and returns a message summarizing how many were added
      def self.call
        new_user_count = new.create_new_users
        "Added #{new_user_count} new user#{new_user_count == 1 ? '' : 's'}."
      end

      # Iterates through newly fetched users and creates records in the DB.
      def create_new_users
        new_user_count = 0
        # Fetch only users whose remote_id exceeds the last synced ID
        new_users = fetch_new_api_users

        new_users.each do |data|
          create_user(data)    # Persist each new user
          new_user_count += 1  # Increment the counter
        end

        new_user_count
      end

      private

      # Retrieves all users via the API client, then selects those with
      # IDs greater than the last_remote_id tracked in Base.
      def fetch_new_api_users
        users = @api_client.fetch_all_users
        users.select { |user| user[:user_id].to_i > @last_remote_id }
      end
    end
  end
end
