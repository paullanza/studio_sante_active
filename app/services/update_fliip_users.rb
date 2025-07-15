class UpdateFliipUsers < FliipApiCaller
  def self.call
    new.update_all_users
  end

  def update_all_users
    @api_client.fetch_users.each do |data|
      if user = FliipUser.find_by(remote_id: data[:user_id])
        update_user(user, data)
      end
    end
  end

  private

  def update_user(user, data)
    user.update!(
      custom_id:           data[:custom_id],
      user_role:           data[:user_role],
      first_name:          data[:user_firstname],
      last_name:           data[:user_lastname],
      gender:              data[:user_gender],
      member_type:         data[:member_type],
      status:              data[:user_status],
      email:               data[:user_email],
      image:               data[:user_image],
      phone1:              data[:user_phone1],
      phone2:              data[:user_phone2],
      dob:                 parse_date(data[:user_dob]),
      address:             data[:user_address],
      city:                data[:user_city],
      zipcode:             data[:user_zipcode],
      language:            data[:user_language],
      profile_step:        data[:profile_step],
      sync_g_cal:          data[:sync_g_cal],
      progress:            data[:progress].to_f,
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
