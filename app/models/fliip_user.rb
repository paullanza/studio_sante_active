class FliipUser < ApplicationRecord
  has_many :fliip_user_notes, dependent: :destroy

  def to_hash
    {
      custom_id: custom_id,
      user_role: user_role,
      user_firstname: user_firstname,
      user_lastname: user_lastname,
      user_gender: user_gender,
      member_type: member_type,
      user_status: user_status,
      user_email: user_email,
      user_image: user_image,
      user_phone1: user_phone1,
      user_phone2: user_phone2,
      user_dob: user_dob&.to_s,
      user_address: user_address,
      user_city: user_city,
      user_zipcode: user_zipcode,
      user_language: user_language,
      profile_step: profile_step,
      sync_g_cal: sync_g_cal,
      member_since: member_since&.to_s,
      custom_field_value: custom_field_value,
      custom_field_option: custom_field_option,
      user_notes: fliip_user_notes.pluck(:note_text, :created_date, :creator_of_note_full_name).map do |note_text, created_date, creator|
        {
          note_text: note_text,
          created_date: created_date&.to_s,
          creator_of_note_full_name: creator
        }
      end,
      appointment_notes: fliip_user_appointment_notes.pluck(:note_text, :created_date, :creator_of_note_full_name, :service_name, :appointment_start).map do |note_text, created_date, creator, service, appointment_start|
        {
          note_text: note_text,
          created_date: created_date&.to_s&.gsub(' UTC', ''),
          creator_of_note_full_name: creator,
          service_name: service,
          appointment_start: appointment_start&.to_s
        }
      end
    }
  end
end
