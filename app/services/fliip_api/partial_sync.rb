module FliipApi
  # A sync run finished, but some users failed. Raised at the end of a job
  # so the run shows as failed in Mission Control, with the users listed.
  class PartialSync < Error; end
end
