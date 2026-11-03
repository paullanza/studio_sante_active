module FliipApi
  # Pure functions from a Fliip API row (symbol keys) to the attributes of
  # the fliip_users, fliip_services and fliip_contracts columns. No database
  # access. Values match what the previous sync stored, so switching to this
  # mapper doesn't rewrite unchanged rows.
  module Mapper
    module_function

    USER_FIELDS = {
      custom_id: :custom_id, user_role: :user_role, user_firstname: :user_firstname,
      user_lastname: :user_lastname, user_gender: :user_gender, member_type: :member_type,
      user_status: :user_status, user_email: :user_email, user_image: :user_image,
      user_phone1: :user_phone1, user_phone2: :user_phone2, user_address: :user_address,
      user_city: :user_city, user_zipcode: :user_zipcode, user_language: :user_language,
      profile_step: :profile_step
    }.freeze

    # Only maps keys present in the row: staff details, for one, have no
    # user_status, and a missing key must not blank the stored value.
    def user(row)
      attrs = { remote_id: Integer(row.fetch(:user_id)) }
      USER_FIELDS.each { |column, key| attrs[column] = row[key] if row.key?(key) }
      attrs[:user_dob] = date(row[:user_dob]) if row.key?(:user_dob)
      attrs[:member_since] = date(row[:member_since]) if row.key?(:member_since)
      attrs
    end

    def service(row)
      {
        remote_purchase_id: Integer(row.fetch(:service_purchase_id)),
        purchase_status: row[:purchase_status],
        start_date: date(row[:start_date]),
        expire_date: date(row[:expire_date]),
        purchase_date: datetime(row[:purchase_date]), # zoneless in Fliip, stored as UTC
        stop_date: date(row[:stop_date]),
        cancel_date: date(row[:cancel_date]),
        rebate: row[:rebate],
        stop_payments: row[:stop_payments] == "1",
        discount_name: row[:discount_name],
        service_id: row[:service_id].to_i,
        service_name: row[:service_name],
        service_type: row[:service_type],
        service_category_name: row[:service_category_name],
        coach: row[:coach],
        payment_terms: row[:payment_terms],
        duration: row[:duration],
        online_enabled: row[:online_enabled],
        service_description: row[:service_description],
        billed_at_purchase: row[:billed_at_purchase].to_i,
        ledger_account: row[:ledger_account]
      }
    end

    def contract(row)
      {
        remote_contract_id: Integer(row.fetch(:contract_id)),
        status: row[:status],
        start_date: date(row[:start_date]),
        end_date: date(row[:end_date]),
        stop_date: date(row[:stop_date]),
        resume_date: date(row[:resume_date]),
        cancel_date: date(row[:cancel_date]),
        rebate: row[:rebate],
        discount_name: row[:discount_name],
        main_user_contract: row[:main_user_contract],
        membership_name: row[:membership_name],
        plan_base_type: row[:plan_base_type],
        plan_type: row[:plan_type],
        plan_description: row[:plan_description],
        plan_classes: row[:plan_classes],
        payment_terms: row[:payment_terms],
        duration: row[:duration],
        billed_at_purchase: row[:billed_at_purchase],
        ledger_account: row[:ledger_account],
        pack_class_num: row[:pack_class_num],
        pack_class_used: row[:pack_class_used]
      }
    end

    # Blank or invalid dates become nil.
    def date(value)
      return nil if value.blank?

      Date.parse(value.to_s)
    rescue Date::Error
      nil
    end

    def datetime(value)
      return nil if value.blank?

      DateTime.parse(value.to_s)
    rescue Date::Error
      nil
    end
  end
end
