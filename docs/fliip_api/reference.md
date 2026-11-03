# FLiiP Admin API v1.2.0 — response structures

Source: https://api.fliipapp.com/v2/swagger.json (OpenAPI 3.1). Base URL in spec: `https://static.fliipapp.com/api/v2`.
Examples in `examples/` use fake data; shapes and types follow the spec. `[]` means array of objects.
`T?` = the spec allows null for that field. Error responses (400/401/403) have no documented body.

## Auth
- `/api/v2` endpoints: studio API Secret key in the `Authorization` header (raw or `Bearer <key>`).
- `/gate/*` endpoints: `secret_key` field in the request body (no header) — except `getCheckedInMembers`, which takes a user Bearer token. The studio's regular API key works as `secret_key`.
- `/gate/*` endpoints are v1-routed: base URL `https://static.fliipapp.com/api`, **not** `/api/v2` (which returns 404 for them).

## Endpoint index

| Example | Method | Path | Auth | Request |
|---|---|---|---|---|
| `users_get.json` | GET | `/users/get` | api_key | query: search_text, offset, limit (max 250) |
| `users_details.json` | GET | `/users/details/{user_id}` | api_key |  |
| `users_visits.json` | GET | `/users/visits/{user_id}` | api_key |  |
| `staff_get.json` | GET | `/staff/get` | api_key | query: search_text, offset, limit (max 250) |
| `staff_details.json` | GET | `/staff/details/{user_id}` | api_key |  |
| `settings_get.json` | GET | `/settings/get` | api_key |  |
| `contracts_get.json` | GET | `/contracts/get/{user_id}` | api_key |  |
| `contracts_get_future.json` | GET | `/contracts/get_future/{user_id}` | api_key |  |
| `contracts_get_history.json` | GET | `/contracts/get_history/{user_id}` | api_key |  |
| `services_get.json` | GET | `/services/get/{user_id}` | api_key |  |
| `services_get_future.json` | GET | `/services/get_future/{user_id}` | api_key |  |
| `services_get_history.json` | GET | `/services/get_history/{user_id}` | api_key |  |
| `payments_get.json` | GET | `/payments/get/{user_id}` | api_key |  |
| `payments_get_history.json` | GET | `/payments/get_history/{user_id}` | api_key |  |
| `payments_get_invoice_html.json` | GET | `/payments/get_invoice_html/{payment_transaction_id}` | api_key | path id is an integer |
| `payments_get_scheduled_future_payments.json` | GET | `/payments/get_scheduled_future_payments/{user_id}` | api_key |  |
| `gate_get_active_members.json` | POST | `/gate/getActiveMembers` | secret_key in body | multipart: secret_key* |
| `gate_get_changed_users.json` | POST | `/gate/getChangedUsers` | secret_key in body | query: since* (ISO 8601 UTC); multipart: secret_key*, limit |
| `gate_member_check_in.json` | POST | `/gate/memberCheckIn` | secret_key in body | multipart: secret_key*, card_id*, zone_id (int|null) |
| `gate_members_check_in.json` | POST | `/gate/membersCheckIn` | secret_key in body | JSON: secret_key*, check_ins*[] (max 100) of {custom_id, created_at} |
| `gate_get_zones.json` | POST | `/gate/getZones` | secret_key in body | multipart: secret_key* |
| `gate_get_checked_in_members.json` | POST | `/gate/getCheckedInMembers` | user_token (Bearer) | multipart: from*, to* (ISO 8601 UTC) |

## Nullable fields (per spec)

- **users_get / users_details**: custom_id, user_gender, user_end_date, classes_left, user_phone1/2, user_dob, user_address, user_city, user_zipcode, progress, all emergency_contact.* / reminder_settings.* / custom_field_option.*, appointment_notes[].service_name & appointment_start
- **staff_get / staff_details**: custom_id, user_phone1/2, user_dob, user_address, user_city, user_zipcode, progress, emergency_contact.*, reminder_settings.*, custom_field_option.*, (details) user_gender
- **users_visits**: class_schedule[].visit_number, all_schedule[].user, all_history[].user, class_history[].instructor_user_id & contract
- **contracts_***: status, start_datetime, end_datetime, stop_date, resume_date, cancel_date, planned_cancel_date, rebate, charge_on_stop, discount_name, main_user_contract, plan_available_to, plan_max_start_date, session_classes[].meeting_url
- **services_***: expire_date, stop_date, cancel_date
- **payments_get_history**: contract_id, membership_name, service_name, service_purchase_id
- **payments_get_scheduled_future_payments**: service_name, membership_name
- **gate_get_active_members**: result.users[].card_id, user_phone, user_address, user_gender, user_dob, main_plan_expiring_date
- **gate_get_changed_users**: custom_id, image_url, user_created_at, payment_due_amount, payment_due_date
- **gate_member_check_in / members_check_in**: result.user_dob, result.vaccinated, result.main_plan_expiring_date
- **gate_get_checked_in_members**: checkins[].check_in_result_message, profile_picture_url, membership_or_service_name, zone_name
- **settings_get**: (spec example) freetrial_allowed

## Notes on the examples

- Ids are mostly **numeric strings** (`user_id`, `contract_id`, …); a few are integers (`class_id` in session_classes, `zone_id`, `working_hours_id`, `check_ins` counts).
- Dates come in several formats: `YYYY-MM-DD`, `YYYY-MM-DD HH:MM:SS`, ISO 8601 (`2021-05-24T08:00:35+00:00`), and display strings like `25 April 2024` (visits).
- `contracts_get`, `_future`, `_history` share one schema (same for `services_*`) — the examples are identical copies.
- `contracts[].amounts.plan_payments[]` has no documented item shape (spec example is `[{}]`); the example uses `[]`.
- `users_get` list items and `users_details` share one schema; staff list vs staff details differ (details adds `working_hours`, drops status/notes/reminders).
- `payments_get[].is_default` is documented as the literal string `"0 not default, 1 default"`; the example uses `"1"`.
- The spec also lists 14 `components.schemas` (User, UserStaff, Studio, Contracts, Services, PaymentMethod, PaymentDetails, CheckinRequest, CheckinInfo, UserVisits, FuturePayment, Status, StatusAppointment, …) but no endpoint references them; the inline response schemas are what these examples follow.
- Request bodies for POST endpoints: see the table above; `_requests_membersCheckIn_body.json` is a sample JSON body.

## Field reference

### users_get
Top level: array

| Field | Type |
|---|---|
| `[].user_id` | string |
| `[].custom_id` | string |
| `[].user_role` | string |
| `[].user_firstname` | string |
| `[].user_lastname` | string |
| `[].user_gender` | string |
| `[].member_type` | string |
| `[].user_end_date` | string |
| `[].classes_left` | integer |
| `[].user_status` | string |
| `[].user_email` | string |
| `[].user_image` | string |
| `[].user_phone1` | string |
| `[].user_phone2` | string |
| `[].user_dob` | string |
| `[].user_address` | string |
| `[].user_city` | string |
| `[].user_zipcode` | string |
| `[].user_language` | string |
| `[].profile_step` | string |
| `[].sync_g_cal` | string |
| `[].progress` | string |
| `[].user_emergency_contact.emergency_contact_name` | string |
| `[].user_emergency_contact.emergency_contact_phone` | string |
| `[].user_emergency_contact.relation_to_member` | string |
| `[].reminder_settings.send_reminders` | string |
| `[].reminder_settings.reminder_type` | string |
| `[].reminder_settings.reminder_setting_email` | string |
| `[].reminder_settings.reminder_setting_mobile` | string |
| `[].reminder_settings.reminder_setting_delay` | string |
| `[].custom_field_value` | string |
| `[].custom_field_option.custom_option_name_en` | string |
| `[].custom_field_option.custom_option_name_fr` | string |
| `[].custom_field_option.custom_option_name_es` | string |
| `[].custom_field_option.custom_option_name_de` | string |
| `[].custom_field_option.custom_option_name_it` | string |
| `[].custom_field_option.custom_option_name_pt` | string |
| `[].member_since` | string |
| `[].user_notes[].note_text` | string |
| `[].user_notes[].created_date` | string |
| `[].user_notes[].creator_of_note_full_name` | string |
| `[].appointment_notes[].note_text` | string |
| `[].appointment_notes[].created_date` | string |
| `[].appointment_notes[].creator_of_note_full_name` | string |
| `[].appointment_notes[].service_name` | string |
| `[].appointment_notes[].appointment_start` | string |
| `[].user_notes[]` | array (shape undocumented) |

### users_details
Top level: object

| Field | Type |
|---|---|
| `user_id` | string |
| `custom_id` | string |
| `user_role` | string |
| `user_firstname` | string |
| `user_lastname` | string |
| `user_gender` | string |
| `member_type` | string |
| `user_end_date` | string |
| `classes_left` | integer |
| `user_status` | string |
| `user_email` | string |
| `user_image` | string |
| `user_phone1` | string |
| `user_phone2` | string |
| `user_dob` | string |
| `user_address` | string |
| `user_city` | string |
| `user_zipcode` | string |
| `user_language` | string |
| `profile_step` | string |
| `sync_g_cal` | string |
| `progress` | string |
| `user_emergency_contact.emergency_contact_name` | string |
| `user_emergency_contact.emergency_contact_phone` | string |
| `user_emergency_contact.relation_to_member` | string |
| `reminder_settings.send_reminders` | string |
| `reminder_settings.reminder_type` | string |
| `reminder_settings.reminder_setting_email` | string |
| `reminder_settings.reminder_setting_mobile` | string |
| `reminder_settings.reminder_setting_delay` | string |
| `custom_field_value` | string |
| `custom_field_option.custom_option_name_en` | string |
| `custom_field_option.custom_option_name_fr` | string |
| `custom_field_option.custom_option_name_es` | string |
| `custom_field_option.custom_option_name_de` | string |
| `custom_field_option.custom_option_name_it` | string |
| `custom_field_option.custom_option_name_pt` | string |
| `member_since` | string |
| `user_notes[].note_text` | string |
| `user_notes[].created_date` | string |
| `user_notes[].creator_of_note_full_name` | string |
| `appointment_notes[].note_text` | string |
| `appointment_notes[].created_date` | string |
| `appointment_notes[].creator_of_note_full_name` | string |
| `appointment_notes[].service_name` | string |
| `appointment_notes[].appointment_start` | string |

### users_visits
Top level: object

| Field | Type |
|---|---|
| `class_schedule[].class_name` | string |
| `class_schedule[].visit_number` | integer |
| `class_schedule[].max_number_of_classes` | integer |
| `class_schedule[].date` | string |
| `class_schedule[].time` | string |
| `class_schedule[].instructor` | string |
| `class_schedule[].instructor_user_id` | string |
| `class_schedule[].contract` | string |
| `class_schedule[].status.status_text` | string |
| `class_schedule[].status.status_code` | string |
| `events_schedule[].event_title` | string |
| `events_schedule[].member_price` | string |
| `events_schedule[].date` | string |
| `events_schedule[].time` | string |
| `events_schedule[].instructor` | string |
| `events_schedule[].instructor_user_id` | string |
| `events_schedule[].status.status_text` | string |
| `events_schedule[].status.status_code` | string |
| `events_history[].event_title` | string |
| `events_history[].member_price` | string |
| `events_history[].date` | string |
| `events_history[].time` | string |
| `events_history[].instructor` | string |
| `events_history[].instructor_user_id` | string |
| `events_history[].status.status_text` | string |
| `events_history[].status.status_code` | string |
| `appointments_schedule[].service_type_name` | string |
| `appointments_schedule[].date` | string |
| `appointments_schedule[].start_time` | string |
| `appointments_schedule[].end_time` | string |
| `appointments_schedule[].professional` | string |
| `appointments_schedule[].professional_user_id` | string |
| `appointments_schedule[].package` | string |
| `appointments_schedule[].status.status_text` | string |
| `appointments_schedule[].status.status_code` | string |
| `appointments_schedule[].status.appointment_status.appointment_status_description` | string |
| `appointments_schedule[].status.appointment_status.appointment_status_code` | string |
| `appointments_schedule[].status.attendance_status.attendance_status_text` | string |
| `appointments_schedule[].status.attendance_status.attendance_status_code` | string |
| `appointments_schedule[].used_hours` | number |
| `appointments_schedule[].duration_hours` | integer |
| `all_schedule[].type` | string |
| `all_schedule[].date` | string |
| `all_schedule[].time` | string |
| `all_schedule[].teacher` | string |
| `all_schedule[].teacher_user_id` | string |
| `all_schedule[].user` | string |
| `all_schedule[].name` | string |
| `all_schedule[].gym_name` | string |
| `all_schedule[].status.status_text` | string |
| `all_schedule[].status.status_code` | string |
| `all_history[].type` | string |
| `all_history[].date` | string |
| `all_history[].time` | string |
| `all_history[].teacher` | string |
| `all_history[].teacher_user_id` | string |
| `all_history[].user` | string |
| `all_history[].name` | string |
| `all_history[].gym_name` | string |
| `all_history[].status.status_text` | string |
| `all_history[].status.status_code` | string |
| `appointments_history[].service_type_name` | string |
| `appointments_history[].date` | string |
| `appointments_history[].start_time` | string |
| `appointments_history[].end_time` | string |
| `appointments_history[].professional` | string |
| `appointments_history[].professional_user_id` | string |
| `appointments_history[].package` | string |
| `appointments_history[].status.status_text` | string |
| `appointments_history[].status.status_code` | string |
| `appointments_history[].status.appointment_status.appointment_status_description` | string |
| `appointments_history[].status.appointment_status.appointment_status_code` | string |
| `appointments_history[].status.attendance_status.attendance_status_text` | string |
| `appointments_history[].status.attendance_status.attendance_status_code` | string |
| `appointments_history[].used_hours` | number |
| `appointments_history[].duration_hours` | integer |
| `class_history[].class_name` | string |
| `class_history[].date` | string |
| `class_history[].day_of_the_week` | string |
| `class_history[].time` | string |
| `class_history[].instructor` | string |
| `class_history[].instructor_user_id` | string |
| `class_history[].contract` | string |
| `class_history[].status.status_text` | string |
| `class_history[].status.status_code` | string |
| `class_history[].status.presence_code` | string |
| `class_history[].status.presence_text` | string |
| `class_recurring[].class_name` | string |
| `class_recurring[].start_date` | string |
| `class_recurring[].end_date` | string |
| `class_recurring[].day_of_the_week` | string |
| `class_recurring[].time_start` | string |
| `class_recurring[].status.status_text` | string |
| `class_recurring[].status.status_code` | string |
| `recurring_appointments[].service_name` | string |
| `recurring_appointments[].instructor` | string |
| `recurring_appointments[].instructor_user_id` | string |
| `recurring_appointments[].start_date` | string |
| `recurring_appointments[].end_date` | string |
| `recurring_appointments[].time_start` | string |
| `recurring_appointments[].status.status_text` | string |
| `recurring_appointments[].status.status_code` | string |

### staff_get
Top level: array

| Field | Type |
|---|---|
| `[].user_id` | string |
| `[].custom_id` | string |
| `[].user_role` | string |
| `[].user_firstname` | string |
| `[].user_lastname` | string |
| `[].user_gender` | string |
| `[].member_type` | string |
| `[].user_status` | string |
| `[].user_email` | string |
| `[].user_image` | string |
| `[].user_phone1` | string |
| `[].user_phone2` | string |
| `[].user_dob` | string |
| `[].user_address` | string |
| `[].user_city` | string |
| `[].user_zipcode` | string |
| `[].user_language` | string |
| `[].profile_step` | string |
| `[].sync_g_cal` | string |
| `[].progress` | string |
| `[].user_emergency_contact.emergency_contact_name` | string |
| `[].user_emergency_contact.emergency_contact_phone` | string |
| `[].user_emergency_contact.relation_to_member` | string |
| `[].reminder_settings.send_reminders` | string |
| `[].reminder_settings.reminder_type` | string |
| `[].reminder_settings.reminder_setting_email` | string |
| `[].reminder_settings.reminder_setting_mobile` | string |
| `[].reminder_settings.reminder_setting_delay` | string |
| `[].custom_field_value` | string |
| `[].custom_field_option.custom_option_name_en` | string |
| `[].custom_field_option.custom_option_name_fr` | string |
| `[].member_since` | string |
| `[].user_notes[].note_text` | string |
| `[].user_notes[].created_date` | string |
| `[].user_notes[].creator_of_note_full_name` | string |
| `[].appointment_notes[].note_text` | string |
| `[].appointment_notes[].created_date` | string |
| `[].appointment_notes[].creator_of_note_full_name` | string |
| `[].appointment_notes[].service_name` | string |
| `[].appointment_notes[].appointment_start` | string |
| `[].user_notes[]` | array (shape undocumented) |

### staff_details
Top level: object

| Field | Type |
|---|---|
| `user_id` | string |
| `custom_id` | string |
| `user_role` | string |
| `user_firstname` | string |
| `user_lastname` | string |
| `user_gender` | string |
| `member_type` | string |
| `user_email` | string |
| `user_image` | string |
| `user_phone1` | string |
| `user_phone2` | string |
| `user_dob` | string |
| `user_address` | string |
| `user_city` | string |
| `user_zipcode` | string |
| `user_language` | string |
| `profile_step` | string |
| `sync_g_cal` | string |
| `progress` | string |
| `user_emergency_contact.emergency_contact_name` | string |
| `user_emergency_contact.emergency_contact_phone` | string |
| `user_emergency_contact.relation_to_member` | string |
| `working_hours[].working_hours_id` | integer |
| `working_hours[].day_of_week` | string |
| `working_hours[].start_time` | string |
| `working_hours[].end_time` | string |
| `working_hours[].start_date` | string |
| `working_hours[].end_date` | string |
| `working_hours[].status` | string |

### settings_get
Top level: object

| Field | Type |
|---|---|
| `gym_id` | string |
| `name` | string |
| `siteurl` | string |
| `address` | string |
| `phone_number` | string |
| `gym_keywords` | string |
| `theme` | string |
| `main_color` | string |
| `gym_timezone` | string |
| `gym_classes_types` | string |
| `unbook_class` | string |
| `unbook_time` | string |
| `unbook_appointment_time` | string |
| `cash_allowed` | string |
| `card_allowed` | string |
| `check_allowed` | string |
| `interac_allowed` | string |
| `direct_debit_allowed` | string |
| `freetrial_allowed` | null |
| `freetrial_classes` | string |
| `freetrial_days` | string |
| `default_language` | string |
| `calendar_start_hour` | string |
| `calendar_end_hour` | string |
| `calendar_daily_hours` | string |
| `service_calendar_start_hour` | string |
| `service_calendar_end_hour` | string |
| `shop_allowed` | string |
| `belt_system_enabled` | string |
| `check_in_enabled` | string |
| `workout_enabled` | string |
| `mailchimp_allowed` | string |
| `late_cancel_enabled` | string |
| `late_cancel_appointment_enabled` | string |
| `messages_enabled` | string |
| `video_enabled` | string |
| `gift_card_enabled` | string |
| `purchase_request_enabled` | string |
| `events_enabled` | string |
| `family_registration` | string |

### contracts_get (also _future, _history)
Top level: array

| Field | Type |
|---|---|
| `[].contract_id` | string |
| `[].status` | string |
| `[].start_date` | string |
| `[].start_datetime` | string |
| `[].end_date` | string |
| `[].end_datetime` | string |
| `[].stop_date` | string |
| `[].resume_date` | string |
| `[].cancel_date` | string |
| `[].planned_cancel_date` | string |
| `[].is_planned_cancellation` | boolean |
| `[].rebate` | string |
| `[].charge_on_stop` | string |
| `[].discount_name` | string |
| `[].main_user_contract` | string |
| `[].membership_name` | string |
| `[].plan_base_type` | string |
| `[].plan_type` | string |
| `[].plan_description` | string |
| `[].plan_available_from` | string |
| `[].plan_available_to` | string |
| `[].plan_min_start_date` | string |
| `[].plan_max_start_date` | string |
| `[].plan_classes` | string |
| `[].payment_terms` | string |
| `[].duration` | string |
| `[].auto_approve` | string |
| `[].offer` | string |
| `[].available_online` | string |
| `[].billed_at_purchase` | string |
| `[].ledger_account` | string |
| `[].tax_tps` | string |
| `[].tax_tvq` | string |
| `[].tps_name` | string |
| `[].tvq_name` | string |
| `[].progression` | integer |
| `[].pack_class_used` | string |
| `[].pack_class_num` | string |
| `[].classes_per_week` | string |
| `[].schedule_stop_date` | string |
| `[].schedule_reactivate_date` | string |
| `[].session_classes[].plan_class_id` | string |
| `[].session_classes[].plan_id` | string |
| `[].session_classes[].class_id` | integer |
| `[].session_classes[].class_type_id` | string |
| `[].session_classes[].class_place` | string |
| `[].session_classes[].class_room_id` | string |
| `[].session_classes[].room_name` | string |
| `[].session_classes[].class_level` | string |
| `[].session_classes[].class_colour` | string |
| `[].session_classes[].class_start` | string |
| `[].session_classes[].class_end` | string |
| `[].session_classes[].class_duration` | string |
| `[].session_classes[].class_day` | string |
| `[].session_classes[].class_teacher_id` | string |
| `[].session_classes[].class_event` | string |
| `[].session_classes[].class_datefrom` | string |
| `[].session_classes[].class_dateto` | string |
| `[].session_classes[].class_description` | string |
| `[].session_classes[].class_trial` | string |
| `[].session_classes[].class_status` | string |
| `[].session_classes[].recurring_subscriptions_allowed` | string |
| `[].session_classes[].meeting_url` | string |
| `[].amounts.billing_amount` | number |
| `[].amounts.plan_payments[]` | array (shape undocumented) |
| `[].amounts.plan_price` | integer |
| `[].amounts.first_payment` | integer |
| `[].amounts.first_payment_no_tax` | number |
| `[].amounts.plan_total_no_tax_no_rebate` | integer |
| `[].amounts.fee` | integer |
| `[].amounts.plan_total_no_tax` | integer |
| `[].amounts.plan_total_amount` | number |
| `[].amounts.rebate` | integer |
| `[].amounts.discount` | integer |
| `[].amounts.is_first_payment_only_promotion` | boolean |
| `[].amounts.first_payment_discount` | integer |
| `[].amounts.tax_amount_1` | number |
| `[].amounts.tax_amount_2` | integer |
| `[].amounts.tax_name_1` | string |
| `[].amounts.tax_name_2` | string |
| `[].amounts.tax_value_1` | string |
| `[].amounts.tax_value_2` | string |
| `[].amounts.total_tax_amount_1` | integer |
| `[].amounts.total_tax_amount_2` | integer |
| `[].amounts.total_no_rebate_tax_amount_1` | integer |
| `[].amounts.total_no_rebate_tax_amount_2` | integer |
| `[].amounts.discounted_amount` | integer |
| `[].amounts.total_discount_value` | integer |
| `[].contract_classes.contract_class_id` | string |
| `[].contract_classes.plan_id` | string |
| `[].contract_classes.class_id` | string |
| `[].contract_classes.contract_id` | string |
| `[].contract_classes.contract_request_id` | string |
| `[].plan_frequencies[].plan_frequency_id` | string |
| `[].plan_frequencies[].plan_price` | string |
| `[].plan_frequencies[].payment_terms` | string |
| `[].plan_frequencies[].plan_duration` | string |

### services_get (also _future, _history)
Top level: array

| Field | Type |
|---|---|
| `[].service_purchase_id` | string |
| `[].purchase_status` | string |
| `[].start_date` | string |
| `[].expire_date` | string |
| `[].purchase_date` | string |
| `[].stop_date` | string |
| `[].cancel_date` | string |
| `[].rebate` | string |
| `[].stop_payments` | string |
| `[].discount_name` | string |
| `[].service_id` | string |
| `[].service_name` | string |
| `[].service_type` | string |
| `[].service_category_name` | string |
| `[].coach` | string |
| `[].payment_terms` | string |
| `[].duration` | string |
| `[].online_enabled` | string |
| `[].service_description` | string |
| `[].service_conditions` | string |
| `[].billed_at_purchase` | string |
| `[].ledger_account` | string |
| `[].progression` | integer |
| `[].amounts.price` | integer |
| `[].amounts.discounted_amount` | integer |
| `[].amounts.billing_amount` | number |
| `[].amounts.first_payment_no_tax` | number |
| `[].amounts.first_payment` | integer |
| `[].amounts.rebate` | integer |
| `[].amounts.discount` | integer |
| `[].amounts.is_first_payment_only_promotion` | boolean |
| `[].amounts.tax_amount_1` | number |
| `[].amounts.tax_amount_2` | number |
| `[].amounts.total_no_tax_no_rebate` | integer |
| `[].amounts.total_no_tax` | integer |
| `[].amounts.total_amount` | number |
| `[].amounts.total_tax_amount_1` | number |
| `[].amounts.total_tax_amount_2` | number |
| `[].amounts.total_no_rebate_tax_amount_1` | integer |
| `[].amounts.total_no_rebate_tax_amount_2` | number |
| `[].amounts.last_rebate` | number |
| `[].amounts.last_discount` | number |
| `[].amounts.last_billing_amount` | number |
| `[].amounts.tax_name_1` | string |
| `[].amounts.tax_name_2` | string |
| `[].amounts.tax_value_1` | string |
| `[].amounts.tax_value_2` | string |
| `[].service_frequencies[].service_frequency_id` | string |
| `[].service_frequencies[].service_id` | string |
| `[].service_frequencies[].price` | string |
| `[].service_frequencies[].billing_cycle_length` | string |
| `[].service_frequencies[].billing_cycle_type` | string |
| `[].service_frequencies[].number_of_payments` | string |
| `[].service_frequencies[].service_length` | string |
| `[].service_frequencies[].service_length_type` | string |
| `[].service_frequencies[].created_at` | string |
| `[].service_frequencies[].updated_at` | string |
| `[].service_frequencies[].service_type` | string |
| `[].service_frequencies[].payment_terms` | string |

### payments_get
Top level: array

| Field | Type |
|---|---|
| `[].payment_id` | string |
| `[].payment_method` | string |
| `[].payment_agreement_date` | string |
| `[].is_default` | string |
| `[].creditcard_name` | string |
| `[].card_type` | string |
| `[].card_number` | string |
| `[].expiration_date` | string |
| `[].mandate_status` | string |
| `[].bank_number` | string |
| `[].transit_number` | string |
| `[].account_number` | string |
| `[].has_image` | string |
| `[].image` | string |

### payments_get_history
Top level: array

| Field | Type |
|---|---|
| `[].payment_history_id` | string |
| `[].payment_history_date` | string |
| `[].amount` | string |
| `[].payment_type` | string |
| `[].payment_history_status` | string |
| `[].trans_id` | string |
| `[].payment_date` | string |
| `[].payment_reason_id` | string |
| `[].payment_card_type` | string |
| `[].balance_payment` | string |
| `[].difference_original_amount` | string |
| `[].payment_description` | string |
| `[].contract_id` | string |
| `[].membership_name` | string |
| `[].payment_type_name` | string |
| `[].payment_history_status_name` | string |
| `[].payment_reason_name` | string |
| `[].product_names[]` | string |
| `[].service_name` | string |
| `[].service_purchase_id` | string |
| `[].auto_rescue` | boolean |

### payments_get_invoice_html
Top level: object

| Field | Type |
|---|---|
| `html` | string |
| `mail` | string |

### payments_get_scheduled_future_payments
Top level: array

| Field | Type |
|---|---|
| `[].amount` | string |
| `[].payment_number` | string |
| `[].payment_date` | string |
| `[].service_name` | string |
| `[].membership_name` | string |

### gate_get_active_members
Top level: object

| Field | Type |
|---|---|
| `error` | boolean |
| `message` | string |
| `code` | integer |
| `result.users[].gym_title` | string |
| `result.users[].plan_title` | string |
| `result.users[].card_id` | string |
| `result.users[].user_phone` | string |
| `result.users[].user_address` | string |
| `result.users[].user_gender` | string |
| `result.users[].user_dob` | string |
| `result.users[].user_image` | string |
| `result.users[].user_firstname` | string |
| `result.users[].user_lastname` | string |
| `result.users[].user_id` | string |
| `result.users[].main_plan_expiring_date` | string |
| `result.users[].zone_ids[]` | integer |

### gate_get_changed_users
Top level: array

| Field | Type |
|---|---|
| `[].user_id` | string |
| `[].user_firstname` | string |
| `[].user_lastname` | string |
| `[].custom_id` | string |
| `[].image_url` | null |
| `[].change_reason` | string |
| `[].user_created_at` | string |
| `[].user_updated_at` | string |
| `[].contract_start_date` | string |
| `[].contract_expiration_date` | string |
| `[].contract_updated_at` | string |
| `[].user_or_contract_updated_at` | string |
| `[].has_payment_due` | boolean |
| `[].payment_due_amount` | integer |
| `[].payment_due_date` | null |
| `[].payment_updated_at` | string |

### gate_member_check_in
Top level: object

| Field | Type |
|---|---|
| `error` | boolean |
| `message` | string |
| `code` | integer |
| `result.id` | string |
| `result.gym_title` | string |
| `result.card_id` | string |
| `result.user_phone` | string |
| `result.user_address` | string |
| `result.user_gender` | string |
| `result.user_dob` | string |
| `result.user_image` | string |
| `result.user_firstname` | string |
| `result.user_lastname` | string |
| `result.vaccinated` | boolean |
| `result.plan_title` | string |
| `result.contract_gym_id` | string |
| `result.contract_gym_name` | string |
| `result.main_plan_expiring_date` | string |
| `result.zone_ids[]` | integer |
| `status` | string |
| `gate_status` | string |

### gate_members_check_in
Top level: array

| Field | Type |
|---|---|
| `[].error` | boolean |
| `[].message` | string |
| `[].code` | integer |
| `[].result.id` | string |
| `[].result.gym_title` | string |
| `[].result.card_id` | string |
| `[].result.user_phone` | string |
| `[].result.user_address` | string |
| `[].result.user_gender` | string |
| `[].result.user_dob` | string |
| `[].result.user_image` | string |
| `[].result.user_firstname` | string |
| `[].result.user_lastname` | string |
| `[].result.vaccinated` | boolean |
| `[].result.plan_title` | string |
| `[].result.contract_gym_id` | string |
| `[].result.contract_gym_name` | string |
| `[].result.main_plan_expiring_date` | string |
| `[].result.zone_ids[]` | integer |
| `[].status` | string |
| `[].gate_status` | string |

### gate_get_zones
Top level: object

| Field | Type |
|---|---|
| `error` | boolean |
| `message` | string |
| `code` | integer |
| `result[].zone_id` | integer |
| `result[].zone_name` | string |

### gate_get_checked_in_members
Top level: object

| Field | Type |
|---|---|
| `gym_id` | string |
| `checkins[].member_id` | string |
| `checkins[].full_name` | string |
| `checkins[].at` | string |
| `checkins[].status` | string |
| `checkins[].check_in_id` | string |
| `checkins[].check_in_result_message` | string |
| `checkins[].additional_message_alert` | string |
| `checkins[].location_alerts[].type` | string |
| `checkins[].location_alerts[].location_count` | integer |
| `checkins[].location_alerts[].location_name` | string |
| `checkins[].message` | string |
| `checkins[].profile_picture_url` | string |
| `checkins[].membership_or_service_name` | string |
| `checkins[].check_in_type` | string |
| `checkins[].is_birthday_today` | boolean |
| `checkins[].zone_name` | string |
| `from` | string |
| `to` | string |
| `count` | integer |

