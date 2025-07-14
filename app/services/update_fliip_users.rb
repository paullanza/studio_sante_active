# app/services/update_fliip_users.rb
class UpdateFliipUsers
  def self.call
    new.update_all_users
  end

  def initialize
    @api = ApiClient.new
  end

  def update_all_users
    @api.fetch_users.each do |data|
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

    # Wipe and re-insert notes to mirror the API payload
    user.fliip_user_notes.delete_all
    insert_user_notes(user, data)

    user.fliip_user_appointment_notes.delete_all
    insert_appointment_notes(user, data)
  end

  def insert_user_notes(user, data)
    Array(data[:user_notes]).each do |note|
      user.fliip_user_notes.create!(
        note_text:                 note[:note_text],
        created_date:              parse_date(note[:created_date]),
        creator_of_note_full_name: note[:creator_of_note_full_name]
      )
    end
  end

  def insert_appointment_notes(user, data)
    Array(data[:user_appointment_notes]).each do |note|
      user.fliip_user_appointment_notes.create!(
        note_text:                 note[:note_text],
        created_date:              parse_date(note[:created_date]),
        creator_of_note_full_name: note[:creator_of_note_full_name],
        service_name:              note[:service_name],
        appointment_start:         parse_date(note[:appointment_start])
      )
    end
  end

  def parse_date(value)
    return nil if value.blank?
    DateTime.parse(value) rescue nil
  end
end
