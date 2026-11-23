# Form builder for the new layout. Renders the `.field` markup from
# docs/ui.md: label, input, hint and the attribute's first error, wired with
# aria-invalid and aria-describedby.
#
#   form_with model: @user, builder: StudioFormBuilder do |f|
#     f.field :email, label: "Courriel", as: :email, autocomplete: "email"
#     f.segmented :present, [ [ "Présent·e", true ], [ "Absent·e", false ] ], label: "Présence"
#     f.submit "Enregistrer"
#   end
class StudioFormBuilder < ActionView::Helpers::FormBuilder
  INPUTS = {
    text: :text_field,
    email: :email_field,
    password: :password_field,
    tel: :telephone_field,
    date: :date_field,
    time: :time_field,
    number: :number_field,
    search: :search_field,
    textarea: :text_area
  }.freeze

  BUTTON_VARIANTS = %i[primary secondary ghost danger].freeze

  # One labelled input. `label_aside` is extra HTML on the label's line (for
  # example the « Mot de passe oublié? » link). Other options go to the input.
  def field(attribute, label:, as: :text, hint: nil, label_aside: nil, **input_options)
    method = INPUTS.fetch(as) { raise ArgumentError, "Unknown field type: #{as.inspect}" }
    error = error_for(attribute)

    input = public_send(method, attribute, input_options.merge(
      class: [ "field__input", input_options[:class] ].compact.join(" "),
      aria: input_aria(attribute, hint:, error:).merge(input_options.fetch(:aria, {}))
    ))

    @template.tag.div(class: field_classes(error)) do
      @template.safe_join([
        label_row(attribute, label, label_aside),
        input,
        hint_tag(attribute, hint),
        error_tag(attribute, error)
      ].compact)
    end
  end

  # A checkbox with its label to the right; the whole row is clickable.
  def check(attribute, label:, **input_options)
    @template.tag.label(class: "checkbox") do
      @template.safe_join([
        check_box(attribute, input_options.merge(class: "checkbox__input")),
        @template.tag.span(label, class: "checkbox__label")
      ])
    end
  end

  # Radio buttons styled as a toggle. `choices` is a list of [label, value].
  def segmented(attribute, choices, label:)
    error = error_for(attribute)
    options = choices.map do |text, value|
      @template.tag.label(class: "segmented__option") do
        @template.safe_join([
          radio_button(attribute, value, class: "segmented__input"),
          @template.tag.span(text, class: "segmented__text")
        ])
      end
    end

    @template.tag.fieldset(class: field_classes(error), aria: { describedby: (error_id(attribute) if error) }) do
      @template.safe_join([
        @template.tag.legend(label, class: "field__label"),
        @template.tag.div(@template.safe_join(options), class: "segmented"),
        error_tag(attribute, error)
      ].compact)
    end
  end

  # A submit button. Only one :primary (gold) button per screen.
  def submit(value = nil, variant: :primary, block: false, **options)
    raise ArgumentError, "Unknown button variant: #{variant.inspect}" unless BUTTON_VARIANTS.include?(variant)

    classes = [ "btn", "btn--#{variant}", ("btn--block" if block), options.delete(:class) ].compact.join(" ")
    button(value || submit_default_value, options.merge(type: "submit", name: nil, class: classes))
  end

  # Errors on :base, shown above the fields.
  def base_errors
    messages = object.respond_to?(:errors) ? object.errors[:base] : []
    return if messages.empty?

    @template.tag.div(class: "flash flash--alert", role: "alert") do
      @template.tag.ul(class: "flash__message flash__list") do
        @template.safe_join(messages.map { |message| @template.tag.li(message) })
      end
    end
  end

  private

  def error_for(attribute)
    return unless object.respond_to?(:errors)

    object.errors[attribute].first
  end

  def field_classes(error)
    [ "field", ("field--invalid" if error) ].compact.join(" ")
  end

  def label_row(attribute, text, aside)
    label_tag = label(attribute, text, class: "field__label")
    return label_tag unless aside

    @template.tag.div(@template.safe_join([ label_tag, aside ]), class: "field__label-row")
  end

  def input_aria(attribute, hint:, error:)
    described_by = [ (hint_id(attribute) if hint), (error_id(attribute) if error) ].compact
    aria = {}
    aria[:invalid] = "true" if error
    aria[:describedby] = described_by.join(" ") if described_by.any?
    aria
  end

  def hint_tag(attribute, hint)
    @template.tag.p(hint, class: "field__hint", id: hint_id(attribute)) if hint
  end

  def error_tag(attribute, error)
    @template.tag.p(error, class: "field__error", id: error_id(attribute)) if error
  end

  def hint_id(attribute)
    field_id(attribute, :hint)
  end

  def error_id(attribute)
    field_id(attribute, :error)
  end
end
