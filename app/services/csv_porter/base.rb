module CsvPorter
  class Base
    require "csv"

    private

    def csv_generate(headers, &block)
      CSV.generate(headers: true) do |csv|
        csv << headers
        yield csv
      end
    end

    def csv_safe_date(d)
      d.present? ? d.strftime("%d/%m/%Y") : nil
    end

    def parse_date(value)
      s = value.to_s.strip
      return nil if s.empty?
      if s =~ %r{\A\d{2}/\d{2}/\d{4}\z}
        Date.strptime(s, "%d/%m/%Y")
      else
        Date.parse(s)
      end
    rescue ArgumentError
      nil
    end

    # Normalize names for loose comparisons (optional)
    def norm_name(s)
      I18n.transliterate(s.to_s.strip.downcase)
    end

    def to_f_or_zero(v)
      s = v.to_s.strip
      return 0.0 if s.empty?
      Float(s)
    rescue ArgumentError
      0.0
    end
  end
end
