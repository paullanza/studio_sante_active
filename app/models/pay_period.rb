# A pay period (« période de paie »): two weeks, Sunday to Saturday inclusive.
# Periods are counted from ANCHOR, both forward and back. A plain value
# object, not stored.
class PayPeriod
  ANCHOR = Date.new(2026, 11, 8) # a Sunday: the period 8–21 Nov 2026
  LENGTH = 14

  MONTHS = %w[janv. févr. mars avr. mai juin juil. août sept. oct. nov. déc.].freeze

  attr_reader :starts_on

  # The period holding `date`. `div` floors, so dates before ANCHOR work too.
  def self.containing(date)
    new(ANCHOR + ((date.to_date - ANCHOR).to_i.div(LENGTH) * LENGTH))
  end

  def self.current(today: Date.current)
    containing(today)
  end

  # From a `?periode=2026-11-08` param; any date inside a period gives that
  # period. Bad or missing input gives the current one.
  def self.from_param(value, today: Date.current)
    containing(Date.iso8601(value.to_s))
  rescue Date::Error
    current(today: today)
  end

  # The current period first, then the ones before it.
  def self.recent(count = 6, today: Date.current)
    first = current(today: today)
    Array.new(count) { |i| new(first.starts_on - (i * LENGTH)) }
  end

  def initialize(starts_on)
    @starts_on = starts_on
  end

  def ends_on
    starts_on + (LENGTH - 1)
  end

  def range
    starts_on..ends_on
  end

  def previous
    self.class.new(starts_on - LENGTH)
  end

  def next
    self.class.new(starts_on + LENGTH)
  end

  def to_param
    starts_on.iso8601
  end

  # « 8 nov. au 21 nov. 2026 », « 29 nov. au 12 déc. 2026 »: day and month
  # on both ends, so every period reads the same; the year once, or on both
  # ends across a year (« 27 déc. 2026 au 9 janv. 2027 »).
  def label
    start_text = "#{starts_on.day} #{MONTHS[starts_on.month - 1]}"
    start_text += " #{starts_on.year}" unless starts_on.year == ends_on.year
    "#{start_text} au #{ends_on.day} #{MONTHS[ends_on.month - 1]} #{ends_on.year}"
  end

  def ==(other)
    other.is_a?(PayPeriod) && other.starts_on == starts_on
  end
  alias eql? ==

  def hash
    starts_on.hash
  end
end
