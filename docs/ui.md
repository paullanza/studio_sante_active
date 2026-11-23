# UI reference: the new layout

How to build a page on the new layout. Every Total Restructure issue builds from this file; `docs/agents/rebuild.md` has the rules for shipping a page. The approved mockups are in `docs/design/`.

## Rules

- Dark only, mobile first: build for 375 px, then check 768 px and desktop.
- One gold button (`.btn--primary`) per screen: the page's main action.
- No Bootstrap classes, no `simple_form`, no inline styles and no raw hex in views or component styles. Colours come from the tokens below.
- Lists are cards on mobile. Admin lists (Confirmations, Personnel, Allocations) become tables from 768 px.
- Touch targets are at least 44 px; inputs and buttons are 48 px, the gold button 52 px.
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

Nav sections: `dashboard`, `clients`, `saisir`, `mes_services`, `plus` (every page reached from the « Plus » menu). The browser tab reads « Ysolde Brisebois · GEKO ». The page sits in `<main class="page">`: a 16 px gutter on mobile and a 960 px column from tablet up. Short signed-out forms use `<div class="page-narrow auth">`. Pages don't repeat the app's name: the brand bar carries it.

## Brand and full-screen web app

The app is called GEKO. Every page starts with the brand bar, « GEKO par Studio Santé Active », linking to the user's landing page (`home_path`), or to sign in when signed out.

GEKO can be added to a phone's home screen and opens full screen:

- `public/manifest.json`: name, `display: standalone`, colours, icons. The icons (`public/icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `favicon.ico`) are placeholders, a gold « G » on the brand green, until there is a logo.
- The layout's `<head>` has the theme colour and the Apple web app tags, with a translucent status bar and `viewport-fit=cover`.
- Content stays clear of the notch and home indicator through the safe-area variables in `studio/_layout.scss`: `--safe-top`, `--safe-right`, `--safe-bottom`, `--safe-left`, and the gutters `--gutter-left` / `--gutter-right`. Anything fixed or sticky to a screen edge must add the matching inset (the nav sticks at `top: var(--safe-top)`).
- An installed app has no browser back button: every page needs a way back (the nav, or `back_link_to`).

## Top nav

Five tabs on every width, icon above label: Dashboard, Clients, Saisir, Mes services, Plus. `nav_tab_to(label, path, section)` renders a tab and marks it active (gold, underlined, `aria-current="page"`) when the page declared that section. « Plus » is a `<details>` menu with no JS. Each item is gated by its policy in the partial: add a page by adding a link inside `if policy(...).action?`, never a role check.

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

Type: `--font-heading` (Barlow) for headings and buttons, `--font-body` (Lato) for everything else. Sizes: page title 30, section 22, card title 17, label 13 uppercase (`.eyebrow`), body 16, secondary 14.

## Components

### Buttons

```erb
<%= link_to "Saisir une séance", new_seance_path, class: "btn btn--primary btn--block" %>
<button type="button" class="btn btn--secondary">Modifier</button>
<button type="button" class="btn btn--ghost">Annuler</button>
<%= button_to "Supprimer", session_path(s), method: :delete, class: "btn btn--danger",
      form: { data: { turbo_confirm: "Supprimer cette séance?" } } %>
```

`.btn--primary` (gold, 52 px, one per screen), `.btn--secondary`, `.btn--ghost`, `.btn--danger`; `.btn--block` for full width.

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

### Progress bars

`bar_with_label(percent:, label:, bg_class:)` and the colour helpers in `ProgressHelper` work unchanged; `studio/_progress.scss` styles their class names (`progress`, `progress-bar`, `bg-primary`, `bg-secondary`, `bg-warning`, `bg-orange`, `bg-danger`, `label-dark`, `label-light`).

### Flash

`notice` and `alert` render automatically in the layout. Notices close after 5 s; alerts stay until closed. Use `alert` for errors.

## Forms: StudioFormBuilder

```erb
<%= form_with model: @user, url: profile_path, builder: StudioFormBuilder, class: "form" do |f| %>
  <%= f.base_errors %>
  <%= f.field :email, label: "Courriel", as: :email, autocomplete: "email" %>
  <%= f.field :password, label: "Mot de passe", as: :password, hint: "8 caractères minimum",
        label_aside: link_to("Mot de passe oublié?", password_help_path) %>
  <%= f.field :note, label: "Note", as: :textarea %>
  <%= f.check :remember_me, label: "Se souvenir de moi" %>
  <%= f.segmented :duration, [ [ "1 h", 1.0 ], [ "30 min", 0.5 ] ], label: "Durée" %>
  <%= f.submit "Enregistrer" %>
<% end %>
```

- `field(attr, label:, as:, hint:, label_aside:, **input_options)`: `as` is `:text` (default), `:email`, `:password`, `:tel`, `:date`, `:time`, `:number`, `:search` or `:textarea`. Renders the label, the input, the hint and the attribute's first error. With an error it adds `.field--invalid`, `aria-invalid="true"` and points `aria-describedby` at the hint and error. Other options (`autocomplete`, `required`, `min`, `step`, …) go to the input.
- `check(attr, label:)`: a checkbox inside its label.
- `segmented(attr, choices, label:)`: radio buttons as a toggle in a `<fieldset>`; `choices` is `[[label, value], …]`. The option matching the current value is checked; the checked option uses `--brand`.
- `submit(label, variant: :primary, block: false)`: a `<button type="submit">` with `.btn--{variant}` (`:primary`, `:secondary`, `:ghost`, `:danger`).
- `base_errors`: errors on `:base` as a `.flash--alert` list above the fields.

Put a form's fields in `class="form"` for the 16 px vertical rhythm. For a field the builder can't render (the Mapbox address box), write the same markup by hand: `.field`, `.field__label`, the control, `.field__error`.

Validation messages are French (`config/locales/fr.yml`); field names come from `activerecord.attributes`. Add a model's attribute names there when its errors show with `full_messages`.
