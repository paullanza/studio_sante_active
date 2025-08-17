module SessionsHelper
  def default_time_slot_str(now: Time.zone.now)
    now   = now.change(sec: 0)
    mins  = now.min >= 30 ? 30 : 0
    slot  = now.change(min: mins)

    day_start = now.change(hour: 6,  min: 0)
    day_last  = now.change(hour: 20, min: 30)

    slot = day_start if slot < day_start
    slot = day_last  if slot > day_last

    slot.strftime("%H:%M")
  end
end
