# Client details on the new layout.
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
end
