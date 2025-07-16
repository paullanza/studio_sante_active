module FliipApi
  module UserSync
    class Base
      def initialize
        @api_client = FliipApi::ApiClient.new
        @last_remote_id = FliipUser.maximum(:remote_id)
      end

      private

      def create_user(data)
        user = insert_user(data)
        sync_notes(user, data)
      end

      def insert_user(data)
        FliipUser.create!(
          remote_id:           data[:user_id],
          custom_id:           data[:custom_id],
          user_role:           data[:user_role],
          user_firstname:          data[:user_firstname],
          user_lastname:           data[:user_lastname],
          user_gender:              data[:user_gender],
          member_type:         data[:member_type],
          user_status:              data[:user_status],
          user_email:               data[:user_email],
          user_image:               data[:user_image],
          user_phone1:              data[:user_phone1],
          user_phone2:              data[:user_phone2],
          user_dob:                 parse_date(data[:user_dob]),
          user_address:             data[:user_address],
          user_city:                data[:user_city],
          user_zipcode:             data[:user_zipcode],
          user_language:            data[:user_language],
          profile_step:        data[:profile_step],
          sync_g_cal:          data[:sync_g_cal],
          member_since:        parse_date(data[:member_since]),
          custom_field_value:  data[:custom_field_value],
          custom_field_option: data[:custom_field_option]
        )
      end

      def sync_notes(user, data)
        insert_appointment_notes(user, data)
        insert_user_notes(user, data)
      end

      def insert_user_notes(user, data)
        Array(data[:user_notes]).each do |note|
          user.fliip_user_notes.create!(
            note_text: note[:note_text],
            created_date: parse_date(note[:created_date]),
            creator_of_note_full_name: note[:creator_of_note_full_name],
          )
        end
      end

      def insert_appointment_notes(user, data)
        Array(data[:appointment_notes]).each do |note|
          user.fliip_user_appointment_notes.create!(
            note_text: note[:note_text],
            created_date: parse_datetime(note[:created_date]),
            creator_of_note_full_name: note[:creator_of_note_full_name],
            service_name: note[:service_name],
            appointment_start: parse_date(note[:appointment_start]),
          )
        end
      end

      def parse_date(value)
        return nil if value.blank?

        Date.parse(value) rescue nil
      end

      def parse_datetime(value)
        return nil if value.blank?

        DateTime.parse(value) rescue nil
      end
    end
  end
end
