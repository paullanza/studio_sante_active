module FliipServicesHelper
  def svc_time_range_label(svc)
    sd = svc.start_date&.strftime("%d/%m/%Y")
    ed = svc.expire_date&.strftime("%d/%m/%Y")
    return "#{sd}–#{ed}" if sd && ed
    return "#{sd}–?"     if sd
    return "?–#{ed}"     if ed
    "—"
  end

  def svc_time_progress_percent(svc)
    start  = svc.start_date || svc.purchase_date&.to_date
    finish = svc.expire_date
    return 0 unless start && finish && finish > start
    (((Date.current - start).to_f / (finish - start).to_f) * 100).clamp(0, 100).round
  end

  # returns a pair of classes for bg + text readability
  def progress_color_classes(percent)
    p = percent.to_i
    return ["bg-secondary", "text-white"] if p <= 0
    case p
    when 0..49   then ["bg-success",  "text-white"]
    when 50..74  then ["bg-warning",  "text-dark"]
    when 75..94  then ["bg-orange",   "text-dark"]  # custom orange (see CSS below)
    else              ["bg-danger",   "text-white"]
    end
  end

  def fmt1(n)
    ("%.1f" % n.to_f)
  end
end
