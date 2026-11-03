module FliipApi
  # Fliip couldn't be reached or answered something unusable, after retries.
  # Callers must treat this as "unknown", never as "no data".
  class Unavailable < Error; end
end
