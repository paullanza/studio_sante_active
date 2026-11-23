# UI reference: the new layout

How to build a page on the new layout. Every Total Restructure issue builds from this file; `docs/agents/rebuild.md` has the rules for shipping a page. The approved mockups are in `docs/design/`.

## Rules

- Dark only, mobile first: build for 375 px, then check 768 px and desktop.
- One gold button (`.btn--primary`) per screen: the page's main action.
- No Bootstrap classes, no `simple_form`, no inline styles and no raw hex in views or component styles. Colours come from the tokens below.
- Lists are cards on mobile. Admin lists (Confirmations, Personnel, Allocations) become tables from 768 px.
- Touch targets are at least 44 px. Buttons, the gold button and one-line fields are 44 px (`--control-height`); a field tile with its label is 50 px. Inputs stay at 16 px text, since iOS zooms in on anything smaller.
- UI copy is French. Dates show as `dd/mm/yyyy`, times as `HH:MM` (`l(date)` gives `dd/mm/yyyy`).
- Icons are inline SVG (`icon_svg`), never an icon font.
- Never show a status with colour alone: badges always carry their label.

## Files

| What | Where |
| -- | -- |
| Layout | `app/views/layouts/studio.html.erb` |
| Top nav | `app/views/layouts/_studio_nav.html.erb` |
| Flash | `app/views/shared/_studio_flash.html.erb`, `flash_controller.js` |
| Helpers | `app/helpers/layout_helper.rb` |
| Form builder | `app/helpers/studio_form_builder.rb` |
| Styles | `app/assets/stylesheets/studio.scss`, partials in `studio/` (each listed with `@use` in `studio.scss`) |
| JS entry | `app/javascript/studio.js` (Turbo and Stimulus, no Bootstrap) |
| Fonts | `app/assets/fonts/` (Barlow 500/600/700, Lato 400/700, OFL licence in `OFL.txt`) |

`bin/dev` builds both stylesheets (`application.css` for the old layout, `studio.css` for this one).

## Putting a page on the layout

```ruby
class FliipUsersController < ApplicationController
  layout "studio"
end
```

Devise pages are on it already (`ApplicationController#layout_for_request`). The old `layouts/application` stays until ENG-216. Moving between the two layouts makes Turbo do a full reload; that is expected.

In the view, declare the nav section, the page title, and a back link instead of a header band:

```erb
<% content_for :nav_section, "clients" %>
<% content_for :title, "Ysolde Brisebois" %>

<%= back_link_to "Clients", fliip_users_path %>
```

Nav sections: `dashboard`, `clients`, `saisir`, `mes_services`, `plus` (every page reached from the « Plus » menu). The browser tab reads « Ysolde Brisebois · GEKO ». The page sits in `<main class="page">`: a 16 px gutter on mobile and a 960 px column from tablet up. A list with many columns declares `content_for :page_wide, true` to use the screen's width (up to 1680 px). Signed-out forms use `auth-split` (see Forms); other short signed-out pages (« Mot de passe oublié ») use `<div class="page-narrow auth">`. Pages don't repeat the app's name: the brand bar carries it.

## Brand and full-screen web app

The app is called GEKO. Every page starts with the brand bar: « GEKO » in Barlow 700, gold (`--accent`), then « par Studio Santé Active » in Lato, light green (`--brand-light`). The brand name is the one gold item besides the page's main action. It links to the user's landing page (`home_path`), or to sign in when signed out.

GEKO can be added to a phone's home screen and opens full screen:

- `public/manifest.json`: name, `display: standalone`, colours, icons. The icons (`public/icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `favicon.ico`) are placeholders, a gold « G » on the brand green, until there is a logo.
- The layout's `<head>` has the theme colour and the Apple web app tags, with a translucent status bar and `viewport-fit=cover`.
- Content stays clear of the notch and home indicator through the safe-area variables in `studio/_layout.scss`: `--safe-top`, `--safe-right`, `--safe-bottom`, `--safe-left`, and the gutters `--gutter-left` / `--gutter-right`. Anything fixed or sticky to a screen edge must add the matching inset (the nav sticks at `top: var(--safe-top)`).
- An installed app has no browser back button: every page needs a way back (the nav, or `back_link_to`).

## Top nav

Five tabs on every width, icon above label: Dashboard, Clients, Saisir, Mes services, Plus. On a phone the brand bar sits above the tabs and only the tabs stick to the top. From 1024 px the brand bar and the tabs share one sticky bar (`.masthead` in the layout), brand on the left. `nav_tab_to(label, path, section)` renders a tab and marks it active (gold, underlined, `aria-current="page"`) when the page declared that section. « Plus » is a `<details>` menu with no JS. Each item is gated by its policy in the partial: add a page by adding a link inside `if policy(...).action?`, never a role check.

## Tokens

CSS custom properties on `:root` (`studio/_tokens.scss`). Use `var(--name)`.

| Token | Value | Use |
| -- | -- | -- |
| `--bg` | #0E1411 | page, input background |
| `--surface` | #16201A | cards, nav, menus |
| `--surface-2` | #1E2B23 | stat tiles, secondary buttons, hovers |
| `--border` | #2C3B31 | separators, input borders |
| `--border-strong` | #3E7A55 | top card, focused input, secondary button |
| `--brand` | #2F6B47 | checked segmented option |
| `--on-brand` | #FFFFFF | text on brand |
| `--brand-light` | #6FBF8E | links, section labels |
| `--accent` | #D4A537 | gold: main action, active tab |
| `--accent-hover` | #E6BE5C | gold hover |
| `--accent-shadow` | #8C6B1F | the gold button's hard shadow |
| `--on-accent` | #14110A | text on gold |
| `--text` | #ECEFEA | text |
| `--text-muted` | #A3B0A7 | secondary text |
| `--danger` | #F08A8A | errors, destructive text |
| `--danger-border` | #8C3A3A | danger button border, alert border |
| `--field-invalid-border` | #C65B5B | invalid input border |
| `--badge-chargee-bg` / `-fg` | #1F3A2A / #8FD6A9 | Chargée |
| `--badge-absence-bg` / `-fg` | #2A2E3D / #A9B8F0 | Absence |
| `--badge-moins24-bg` / `-fg` | #3D2E1A / #F2B66D | -24h, overrun |
| `--badge-unconfirmed-bg` / `-fg` | #33301A / #E6CC6A | Non confirmée |
| `--badge-retire-bg` / `-fg` | #3A1F22 / #F08A8A | Retiré de Fliip |
| `--progress-*` | #0D6EFD, #6C757D, #FFC107, #FD7E14, #DC3545 | progress bars (unchanged) |

Type: `--font-heading` (Barlow) for headings and buttons, `--font-body` (Lato) for everything else. Sizes: page title 26, section 20, card title 16, label 12 uppercase (`.eyebrow`), body 15, secondary 13, inputs 16. Only these fonts and weights exist: Barlow 500, 600, 700 and Lato 400, 700. Never set another family (use the two tokens) or another weight: a Lato 600 or a Barlow 400 is faked by the browser.

## Components

### Buttons

```erb
<%= link_to new_seance_path, class: "btn btn--primary" do %>
  <%= safe_join([ "Saisir une séance", button_arrow ]) %>
<% end %>
<%= link_to edit_user_path(@user), class: "btn btn--secondary" do %>
  <%= safe_join([ "Modifier", button_arrow ]) %>
<% end %>
<button type="button" class="btn btn--ghost">Annuler</button>
<%= button_to "Supprimer", session_path(s), method: :delete, class: "btn btn--danger",
      form: { data: { turbo_confirm: "Supprimer cette séance?" } } %>
```

Buttons must not look like Bootstrap: no rounded boxes in a row. Labels are Barlow in small caps.

- `.btn--primary`: the gold main action, one per screen, 52 px. A block with a cut bottom-right corner on a hard gold shadow (`--accent-shadow`) that it presses into when clicked.
- `.btn--secondary`: green underlined text. `.btn--danger`: red underlined text. `.btn--ghost`: plain muted text. None of them has a box.
- `button_arrow` (`LayoutHelper`) adds the arrow that slides on hover. Forward actions (primary, secondary) carry it; `StudioFormBuilder#submit` adds it to those two variants itself.
- `.btn--block` for full width (a form's actions do this on a phone already).

### Badges

```erb
<span class="badge badge--chargee">Chargée</span>
<span class="badge badge--absence">Absence</span>
<span class="badge badge--moins24">-24h</span>
<span class="badge badge--overrun">12 mois + 17 j</span>
<span class="badge badge--unconfirmed">Non confirmée</span>
<span class="badge badge--retire">Retiré de Fliip</span>
<span class="badge badge--neutral">Toutes les séances utilisées</span>
<span class="text-unconfirmed">Non confirmée</span>
```

`.badge--neutral` is for inactive states and « Toutes les séances utilisées ». `.text-unconfirmed` is the plain-text form.

A service's status badge comes from `service_status_badge(svc)` (`ServiceBadgesHelper`): « Retiré de Fliip » when the service or its client is removed from Fliip, « Toutes les séances utilisées » when a set allocation is used up, else the Fliip status (Actif `--chargee`, Planifié `--absence`, Suspendu `--moins24`, others `--neutral`). `contract_status_badge(contract)` does the same for an abonnement.

### Cards and stat tiles

```erb
<section class="card card--top">
  <h1>Ysolde Brisebois</h1>
  <div class="stats">
    <div class="stat"><span class="stat__value">10</span><span class="stat__label">séances restantes</span></div>
  </div>
</section>

<article class="card">…</article>
```

`.card--top` is the one key-information card at the top of Service and Client pages.

### Tabs

Server-rendered links with a `?tab=` param:

```erb
<nav class="tabs" aria-label="Sections">
  <%= link_to "Services (2)", fliip_user_path(@client, tab: "services"), class: "tabs__tab",
        aria: { current: (@tab == "services" ? "page" : nil) } %>
</nav>
```

### Lists and tables

```erb
<ul class="list until-tablet">
  <li class="card">…</li>
</ul>

<table class="table from-tablet">
  <thead><tr><th>Date</th><th>Client·e</th></tr></thead>
  <tbody><tr><td>13/11/2026</td><td>Ysolde Brisebois</td></tr></tbody>
</table>
```

`.until-tablet` shows only below 768 px and `.from-tablet` only from 768 px: when a page needs both, render the cards with one and the table with the other.

### Search pages and client cards

```erb
<%= form_with url: fliip_users_path, method: :get, class: "search-form", role: "search" do %>
  <div class="field search-form__field">
    <label class="field__box" for="query">
      <span class="field__label">Nom, courriel ou téléphone</span>
      <%= search_field_tag :query, @query, id: "query", class: "field__input" %>
    </label>
  </div>
  <button type="submit" class="btn btn--primary">Rechercher</button>
<% end %>

<div class="client-list">
  <div class="client-list__head" aria-hidden="true"><span>Client</span>…</div>
  <ul class="list"><%= render partial: "fliip_users/client_card", collection: @fliip_users, as: :client, locals: { recent: … } %></ul>
</div>

<%= render "shared/pager", pagy: @pagy %>
```

The search bar stacks on a phone and sits beside its button from 768 px. Its field is `.field--compact`: one line, 44 px, the label visually hidden and the placeholder saying what to type. A client is a `.client-card` on every width: stacked on a phone, its parts in columns under `.client-list__head` from 1024 px, so desktop rows stand out from the page like the phone cards. The name's `.client-card__link` covers the card; a link inside it (the service) sits above with `position: relative; z-index: 1`. `client_avatar(client)` shows the Fliip photo or the initials.

`render "shared/pager", pagy: @pagy` gives page links (‹ 1 … 5 6 7 … 41 ›, from `pager_series`) that keep the request's other params, such as the search. Put it above the list in a `.list-toolbar` beside the count, and again under the list.

### Progress bars

`bar_with_label(percent:, label:, bg_class:)` and the colour helpers in `ProgressHelper` work unchanged; `studio/_progress.scss` styles their class names (`progress`, `progress-bar`, `bg-primary`, `bg-secondary`, `bg-warning`, `bg-orange`, `bg-danger`, `label-dark`, `label-light`).

### Flash

`notice` and `alert` render automatically in the layout. Notices close after 5 s; alerts stay until closed. Use `alert` for errors.

## Forms: StudioFormBuilder

Forms must not look like Bootstrap: no label stacked above an outlined box, no single narrow column on desktop, no full-width bar of a button on desktop. Every form uses the pieces below. The mockups in `docs/design/` predate this field style; where they differ, this section wins until they are updated. `devise/registrations/new.html.erb` is the reference page.

### Fields: filled tiles

```erb
<%= form_with model: @user, url: profile_path, builder: StudioFormBuilder, class: "form" do |f| %>
  <%= f.base_errors %>
  <%= f.field :email, label: "Courriel", as: :email, autocomplete: "email" %>
  <%= f.field :password, label: "Mot de passe", as: :password, hint: "8 caractères minimum",
        label_aside: link_to("Mot de passe oublié?", password_help_path) %>
  <%= f.field :note, label: "Note", as: :textarea, field_class: "form-grid__wide" %>
  <%= f.code :signup_code_token, label: "Code reçu de votre gestionnaire", length: 8 %>
  <%= f.check :remember_me, label: "Se souvenir de moi" %>
  <%= f.segmented :duration, [ [ "1 h", 1.0 ], [ "30 min", 0.5 ] ], label: "Durée" %>
  <%= f.submit "Enregistrer" %>
<% end %>
```

A field is a filled tile (`.field__box`, `--surface-2`, no outline) holding its label in small caps and its input; the hint and error sit under the tile. Focus draws a gold underline on the tile and turns the label gold; an error draws a red underline and turns the label red.

- `field(attr, label:, as:, hint:, label_aside:, field_class:, **input_options)`: `as` is `:text` (default), `:email`, `:password`, `:tel`, `:date`, `:time`, `:number`, `:search` or `:textarea`. With an error it adds `.field--invalid`, `aria-invalid="true"` and points `aria-describedby` at the hint and error. `label_aside` goes on the label's line inside the tile; `field_class` goes on the wrapper (`form-grid__wide`). Other options (`autocomplete`, `required`, `min`, `step`, …) go to the input.
- `code(attr, label:, length:, hint:, autofocus:)`: a fixed-length code typed into one cell per character, split in two halves. `code_input_controller.js` moves between cells, takes a paste, uppercases, and joins the cells into a hidden input, the only one that submits.
- `check(attr, label:)`: a checkbox inside its label.
- `segmented(attr, choices, label:)`: radio buttons as a toggle in a `<fieldset>`; `choices` is `[[label, value], …]`. The option matching the current value is checked; the checked option uses `--brand`.
- `submit(label, variant: :primary, block: false)`: a `<button type="submit">` with `.btn--{variant}` (`:primary`, `:secondary`, `:ghost`, `:danger`).
- `base_errors`: errors on `:base` as a `.flash--alert` list above the fields.

For a field the builder can't render (the Mapbox address box), write the tile by hand: `.field` (plus `.field--invalid` with an error) › `.field__box` › `.field__label` and the control, then `.field__error` after the box. For the address, put `data-controller="address-autocomplete"` and the `MAPBOX_API_KEY` value on the `.field__box`, with a hidden `address` input as the controller's `address` target; the controller inserts `<mapbox-search-box>` after it, borderless on the tile's background.

### Form layout

Mobile first, but on desktop a form is a full-page layout, not a phone column.

```erb
<%= form_with …, class: "form" do |f| %>
  <section class="form-section" aria-labelledby="partie-coordonnees">
    <header class="form-section__head"><h2 id="partie-coordonnees">Vos coordonnées</h2><span>Aide courte</span></header>
    <div class="form-grid">
      <%= f.field :first_name, label: "Prénom" %>
      <%= f.field :last_name, label: "Nom" %>
      <%= f.field :address, label: "Adresse", field_class: "form-grid__wide" %>
    </div>
  </section>
  <div class="form-actions"><%= f.submit "Enregistrer" %></div>
<% end %>
```

- `.form` stacks its children 16 px apart, 28 px when they are sections.
- `.form-section` groups related fields under a Barlow heading, with an optional short note on the right. Split any form of more than about five fields into sections.
- `.form-grid` lays the fields in two columns from 768 px, in source order (the mobile order); `.form-grid__wide` spans both.
- `.form-actions` closes the form: the button is full width on a phone, right-aligned under a rule from 768 px.

### Signed-out pages: auth split

Sign in and sign up use `<div class="auth-split">`: a welcome panel (`.auth-split__panel`: `.eyebrow`, `.auth-split__title` as the page's `h1`, `.auth-split__lead`) and the form (`.auth-split__form`). On a phone they stack; from 1024 px the panel is a sticky card in a 300 px column beside the form. The way to the other page is an `.auth-switch` card (a line of context and a `.btn--secondary` link with `button_arrow`) inside `.form-actions`, after the gold button: under it on a phone, on its left from 768 px. A sectioned form can list its parts in the panel with `.form-parts`; the part holding focus lights up gold through `:has` (see `.signup` in `studio/_layout.scss`).

Validation messages are French (`config/locales/fr.yml`); field names come from `activerecord.attributes`. Add a model's attribute names there when its errors show with `full_messages`.
