# Drawings for « Personnel » (StaffOverview): the period's séances split by
# outcome, and the séances-per-week trend. Inline SVG, sized by attributes and
# coloured by class (studio/_personnel.scss), so the page carries no inline style.
module UsersHelper
  OUTCOME_SEGMENTS = [ [ :chargees, "chargee" ], [ :absences, "absence" ], [ :moins24, "moins24" ] ].freeze

  # A thin bar: Présent·e, Absence and -24h in their colours, in proportion.
  def outcome_bar(row)
    total = row.sessions
    label = "#{row.chargees} présent·e, #{row.absences} absence, #{row.moins24} -24h"
    x = 0.0
    segments = OUTCOME_SEGMENTS.filter_map do |attr, kind|
      count = row.public_send(attr)
      next if total.zero? || count.zero?

      width = count * 100.0 / total
      rect = tag.rect(x: x.round(2), y: 0, width: width.round(2), height: 6, class: "outcome-bar__#{kind}")
      x += width
      rect
    end
    tag.svg(safe_join(segments), class: "outcome-bar", viewBox: "0 0 100 6", preserveAspectRatio: "none",
                                 role: "img", aria: { label: label })
  end

  # One bar per week, the latest in gold; a week with none keeps a faint baseline.
  def trend_sparkline(trend)
    max = [ trend.max.to_i, 1 ].max
    bars = trend.each_with_index.map do |count, i|
      height = (count * 24.0 / max).round(1)
      tag.rect(x: i * 10, y: 24 - height, width: 7, height: [ height, 1 ].max, rx: 1,
               class: [ "trend__bar", ("trend__bar--now" if i == trend.size - 1), ("trend__bar--empty" if count.zero?) ].compact.join(" "))
    end
    tag.svg(safe_join(bars), class: "trend", viewBox: "0 0 #{trend.size * 10 - 3} 24", role: "img",
                             aria: { label: "Séances par semaine, #{trend.size} dernières : #{trend.join(', ')}" })
  end

  # « aujourd'hui », « hier », « il y a 9 j », « jamais ».
  def last_session_label(row, today = Date.current)
    days = row.days_since_last(today)
    case days
    when nil then "jamais"
    when 0 then "aujourd'hui"
    when 1 then "hier"
    else "il y a #{days} j"
    end
  end

  # « 2 vendues », « 1 vendue », « — » with no consultation.
  def sales_label(row)
    return "—" if row.consultations.zero?

    "#{row.sales} #{row.sales > 1 ? 'vendues' : 'vendue'}"
  end
end
