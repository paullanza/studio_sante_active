module FliipApi
  module UserSync
    class Base
      def initialize
        @api_client = FliipApi::ApiClient.new
        @last_remote_id = FliipUser.maximum(:remote_id)
      end

      private

      def fetch_all_api_users
        @api_client.fetch_all_users
      end

      def fetch_new_api_users
        users = @api_client.fetch_all_users
        users.select { |user| user[:user_id].to_i > @last_remote_id }
      end

      def api_users_ids(api_data)
        api_data.map { |user| user[:user_id].to_i }
      end

      def load_local_users
        FliipUser.all.index_by(&:remote_id)
      end

      def create_user(data)
        user = FliipUser.create!(user_attributes(data))
        insert_user_notes(user, data)
      end

      def user_attributes(data)
        {
          remote_id: data[:user_id].to_i,
          custom_id: data[:custom_id],
          user_role: data[:user_role],
          user_firstname: data[:user_firstname],
          user_lastname: data[:user_lastname],
          user_gender: data[:user_gender],
          member_type: data[:member_type],
          user_status: data[:user_status],
          user_email: data[:user_email],
          user_image: data[:user_image],
          user_phone1: data[:user_phone1],
          user_phone2: data[:user_phone2],
          user_dob: parse_date(data[:user_dob]),
          user_address: data[:user_address],
          user_city: data[:user_city],
          user_zipcode: data[:user_zipcode],
          user_language: data[:user_language],
          profile_step: data[:profile_step],
          sync_g_cal: data[:sync_g_cal],
          member_since: parse_date(data[:member_since]),
          custom_field_value: data[:custom_field_value],
          custom_field_option: data[:custom_field_option]
        }
      end

      # Build a hash of note attributes from API data
      def note_attributes(data)
        {
          note_text: data[:note_text],
          created_date: parse_date(data[:created_date]),
          creator_of_note_full_name: data[:creator_of_note_full_name]
        }
      end

      def insert_user_notes(user, data)
        Array(data[:user_notes]).each do |note|
          user.fliip_user_notes.create!(note_attributes(note))
        end
      end

      def parse_date(value)
        return nil if value.blank?

        Date.parse(value) rescue nil
      end
    end
  end
end
