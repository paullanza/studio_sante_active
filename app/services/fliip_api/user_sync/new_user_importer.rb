module FliipApi
  module UserSync
    # NewUserImporter imports users created after the last sync from the Fliip API
    class NewUserImporter < Base
      # Entry point: calls create_new_users and returns a message summarizing how many were added
      def self.call
        info = new.upsert_new_users
        completion_message(info)
      end

      def upsert_new_users
        start_time = Time.now
        new_users = 0
        updated_users = 0

        fetch_new_api_users.each do |data|
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

      # Retrieves all users via the API client, then selects those with
      # IDs greater than the last_remote_id tracked in Base.
      def fetch_new_api_users
        users = @api_client.fetch_all_users
        users.select { |user| user[:user_id].to_i > @last_remote_id }
      end
    end
  end
end
