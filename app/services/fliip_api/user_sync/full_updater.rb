module FliipApi
  module UserSync
    class FullUpdater < Base
      def self.call
        new.update_all_users
        true
      end

      def update_all_users
        api_data = @api_client.fetch_users
        remote_ids = api_data.map { |data| data[:user_id].to_i }

        exisiting_users = FliipUser.where(remote_id: remote_ids).index_by(&:remote_id)

        api_data.each do |data|
          remote_id = data[:user_id].to_i

          if exisiting_users[remote_id].to_hash.to_a - data.to_a == []
            user = exisiting_users[remote_id]
            update_user(user, data)
          else
            create_user(data)
          end
        end
      end

      private

      def update_user(user, data)
        user.update!(
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

        user.fliip_user_notes.delete_all
        insert_user_notes(user, data)

        user.fliip_user_appointment_notes.delete_all
        insert_appointment_notes(user, data)
      end
    end
  end
end
