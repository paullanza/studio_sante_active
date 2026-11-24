# Séance and absence counts are floats (a 30 min séance counts as half).
# Shown French style, without a trailing « ,0 »: 1.0 → « 1 », 1.5 → « 1,5 ».
module CountsHelper
  def format_count(value)
    number_with_precision(value.to_f, precision: 2, strip_insignificant_zeros: true, separator: ",", delimiter: " ")
  end
end
