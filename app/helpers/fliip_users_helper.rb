# Client details on the new layout: photo and membership length.
module FliipUsersHelper
  FLIIP_DEFAULT_IMAGE = "/default.png".freeze

  # The client's Fliip photo, or their initials when Fliip only has its default image.
  def client_avatar(client)
    if client.user_image.present? && !client.user_image.end_with?(FLIIP_DEFAULT_IMAGE)
      image_tag client.user_image, alt: "", class: "avatar", width: 44, height: 44,
        loading: "lazy", referrerpolicy: "no-referrer"
    else
      initials = "#{client.user_firstname.to_s.first}#{client.user_lastname.to_s.first}".upcase
      tag.span(initials.presence || "?", class: "avatar avatar--initials", aria: { hidden: true })
    end
  end

  # « 5 ans 7 mois », « 3 mois », « Moins d'un mois ».
  def membership_length(since, today: Date.current)
    return if since.blank? || since > today

    months = (today.year * 12 + today.month) - (since.year * 12 + since.month)
    months -= 1 if today.day < since.day
    years, months = months.divmod(12)

    parts = []
    parts << "#{years} #{years == 1 ? 'an' : 'ans'}" if years.positive?
    parts << "#{months} mois" if months.positive?
    parts.any? ? parts.join(" ") : "Moins d'un mois"
  end
end
