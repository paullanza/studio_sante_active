# Client phone numbers as staff read them. Fliip stores them mostly as E.164
# (« +15145810994 »), with some European numbers and some junk (« us », « - »).
# Display only: the stored value is Fliip's and is never rewritten.
#
#   format_phone("+15145810994")  # => "(514) 581-0994"
#   format_phone("+33687831427")  # => "+33 6 87 83 14 27"
#   format_phone("+447709959023") # => "+44 7709959023"
#   format_phone("06 12 34 56 78") # => "+33 6 12 34 56 78"
#   format_phone("us")            # => "us" (and phone_href is nil)
module PhoneHelper
  # Canadian numbers sometimes arrive as « + » and 10 digits, the 1 missing.
  # Checked against Québec area codes, since « +43… » could also be Austria.
  QUEBEC_AREA_CODES = %w[263 354 367 418 438 450 514 579 581 819 873].freeze
  # Country codes seen in the data, longest first so « 351 » wins over « 35 ».
  COUNTRY_CODES = %w[351 31 32 33 34 39 41 43 44 49 51 52 55].freeze

  def format_phone(raw)
    country, national = parse_phone(raw)
    return raw.to_s.strip if national.nil?

    case country
    when "1"  then "(#{national[0, 3]}) #{national[3, 3]}-#{national[6, 4]}"
    when "33" then national.size == 9 ? "+33 #{national[0]} #{national[1..].scan(/\d\d/).join(' ')}" : "+33 #{national}"
    when nil  then "+#{national}"
    else "+#{country} #{national}"
    end
  end

  # The tel: link, country code included; nil when it isn't a phone number.
  def phone_href(raw)
    country, national = parse_phone(raw)
    "tel:+#{country}#{national}" if national
  end

  private

  # [country code, national digits]; the country code is nil for an
  # international number with an unknown code. Nil when not a phone number.
  def parse_phone(raw)
    text = raw.to_s.strip
    return nil if text.match?(/\p{L}/)

    digits = text.gsub(/\D/, "")
    # « 00 » is the international prefix dialled from Europe.
    international = text.start_with?("+") || digits.start_with?("00")
    digits = digits.delete_prefix("00")
    return nil if digits.size < 7

    if (typo = digits.match(/\A1[01]([2-9]\d{9})\z/))
      # « +1 » followed by a stray 0 or 1 before the area code.
      north_american(typo[1])
    elsif digits.size == 11 && digits.start_with?("1")
      north_american(digits[1..])
    elsif !international && digits.size == 10 && digits.start_with?("0")
      # A French number in national form (« 06 12 34 56 78 »): no North
      # American number starts with 0.
      [ "33", digits[1..] ]
    elsif digits.size == 10 && (!international || QUEBEC_AREA_CODES.include?(digits[0, 3]))
      north_american(digits)
    elsif international
      code = COUNTRY_CODES.find { |c| digits.start_with?(c) }
      code ? [ code, digits[code.size..] ] : [ nil, digits ]
    end
  end

  # Area codes never start with 0 or 1.
  def north_american(digits)
    [ "1", digits ] if digits.match?(/\A[2-9]/)
  end
end
