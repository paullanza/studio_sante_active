module FliipApi
  module UserSync
    # UserImporter handles a full sync of users from the Fliip API into our local database
    class UserImporter < Base
      # Entry point: builds a new instance, runs the sync, and returns a summary string
      def self.call
        info = new.upsert_all_users
        completion_message(info)
      end

      # Insert or update a user record based on its remote_id,
      # then always sync their contracts. Returns a status string.
      def upsert_all_users
        start_time = Time.now
        new_users = 0
        updated_users = 0

        fetch_all_api_users.each do |data|
          case upsert_user(data)
          when "new" then new_users += 1
          when "updated" then updated_users += 1
          end
        end
        end_time = Time.now

        {
          new_users: new_users,
          updated_users: updated_users,
          start_time: start_time,
          end_time: end_time
        }
      end

      private

      # Delegates to the API client to fetch all users from Fliip's service
      # Abstracted here to keep external HTTP logic out of the sync loop
      def fetch_all_api_users
        @api_client.fetch_all_users
      end
    end
  end
end
