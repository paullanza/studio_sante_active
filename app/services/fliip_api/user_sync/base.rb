module FliipApi
  module UserSync
    # Base class for syncing users (and their contracts) from the Fliip API.
    # Provides shared setup and core helpers for all sync strategies.
    class Base
      # Initialize the API client and track the last synced remote_id
      def initialize
        @api_client = FliipApi::ApiClient.new
        # Track the highest remote_id in the users table for potential incremental fetches
        @last_remote_id = FliipUser.maximum(:remote_id)
      end

      def self.completion_message(info)
        seconds = (info[:end_time] - info[:start_time])
        elapsed_time = Time.at(seconds).utc.strftime("%-H hours, %-M minutes, %-S seconds")
        plural_one = info[:new_users] != 1 ? 'users' : 'user'
        plural_two = info[:updated_users] != 1 ? 'users' : 'user'
        ServiceDefinition.create_missing_definitions!
        part_one = "Sync complete: Elapsed time: #{elapsed_time} | "
        part_two = "#{info[:new_users]} new #{plural_one}, #{info[:updated_users]} updated #{plural_two}."
        part_one + part_two
      end

      private

      # Insert or update a user record based on its remote ID and associated user.
      def upsert_user(data)
        attrs = user_attributes(data)
        user = FliipUser.find_or_initialize_by(remote_id: attrs[:remote_id])
        is_new = user.new_record?

        user.assign_attributes(attrs)
        is_changed = !is_new && user.changed?

        # Persist if it's new or changed
        if is_new || is_changed
          user.save!
        end

        # Delegate all contract and service syncing in two calls
        FliipApi::UserSync::ContractSync.call(user)
        FliipApi::UserSync::ServiceSync.call(user)

        return "new" if is_new

        return "updated" if is_changed

        "unchanged"
      end

      # Build a permitted attributes hash for mass-assignment
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
          member_since: parse_date(data[:member_since])
        }
      end

      # Parse a date string into a Date object, nil if invalid or blank
      def parse_date(value)
        return nil if value.blank?

        Date.parse(value) rescue nil
      end

      # Parse a datetime string into a DateTime object, nil if invalid or blank
      def parse_datetime(value)
        return nil if value.blank?

        DateTime.parse(value) rescue nil
      end
    end
  end
end
