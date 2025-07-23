module FliipApi
  module UserSync
    # Base class for syncing users from the Fliip API
    # Holds shared methods and setup for different sync strategies
    class Base
      # Initialize the API client and track the last synced remote_id
      def initialize
        @api_client     = FliipApi::ApiClient.new
        # Track the highest remote_id in the users table for potential incremental fetches
        @last_remote_id = FliipUser.maximum(:remote_id)
      end

      private

      # Create a new FliipUser record from API data
      def create_user(data)
        FliipUser.create!(user_attributes(data))
        # Suggestion: add Rails.logger.info "Created user #{data[:user_id]}" for debugging
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

      # Parse a date string into a Date object, nil if invalid or blank
      def parse_date(value)
        return nil if value.blank?

        Date.parse(value) rescue nil
      end
    end
  end
end
