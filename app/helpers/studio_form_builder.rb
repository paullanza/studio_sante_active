# Form builder for the new layout. Renders the `.field` markup from
# docs/ui.md: a filled tile holding the label and input, then the hint and the
# attribute's first error, wired with aria-invalid and aria-describedby.
#
#   form_with model: @user, builder: StudioFormBuilder do |f|
#     f.field :email, label: "Courriel", as: :email, autocomplete: "email"
#     f.code :signup_code_token, label: "Code d'inscription", length: 8
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
  # example the « Mot de passe oublié? » link). `field_class` goes on the
  # wrapper (e.g. "form-grid__wide"). Other options go to the input.
  def field(attribute, label:, as: :text, hint: nil, label_aside: nil, field_class: nil, **input_options)
    method = INPUTS.fetch(as) { raise ArgumentError, "Unknown field type: #{as.inspect}" }
    error = error_for(attribute)

    input = public_send(method, attribute, input_options.merge(
      class: [ "field__input", input_options[:class] ].compact.join(" "),
      aria: input_aria(attribute, hint:, error:).merge(input_options.fetch(:aria, {}))
    ))

    @template.tag.div(class: [ field_classes(error), field_class ].compact.join(" ")) do
      @template.safe_join([
        @template.tag.div(@template.safe_join([ label_row(attribute, label, label_aside), input ]), class: "field__box"),
        hint_tag(attribute, hint),
        error_tag(attribute, error)
      ].compact)
    end
  end

  # A fixed-length code (the signup code) typed into one cell per character.
  # The cells have no name: code_input_controller.js joins them into the
  # hidden input that submits. On a re-render the cells show the typed value.
  def code(attribute, label:, length:, hint: nil, autofocus: false)
    error = error_for(attribute)
    value = object.public_send(attribute).to_s
    label_id = field_id(attribute, :label)

    cells = Array.new(length) do |index|
      @template.tag.input(
        type: "text", value: value[index], id: (field_id(attribute) if index.zero?),
        class: "code__cell", maxlength: 1, autocomplete: "off", autocapitalize: "characters",
        spellcheck: false, autofocus: (autofocus if index.zero?),
        aria: { label: "Caractère #{index + 1} sur #{length}", invalid: ("true" if error) },
        data: { code_input_target: "cell",
                action: "input->code-input#input keydown->code-input#keydown paste->code-input#paste focus->code-input#select" }
      )
    end

    @template.tag.div(class: field_classes(error), data: { controller: "code-input" }) do
      @template.safe_join([
        label(attribute, label, class: "field__label", id: label_id),
        @template.tag.div(@template.safe_join(cells), class: "code", role: "group",
                          aria: { labelledby: label_id }.merge(input_aria(attribute, hint:, error:).except(:invalid))),
        hidden_field(attribute, data: { code_input_target: "value" }),
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
