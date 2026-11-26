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

The app is called GEKO. Every page starts with the brand bar: « GEKO » in Barlow 700, gold (`--accent`), then « par Studio Santé Active » in Lato, light green (`--brand-light`). The brand name is the one gold item besides the page's main action. It links to the user's landing page (`home_path`), or to sign in when signed out. Signed in, the staff member's name (`.signed-in-as`, muted, cut with « … » when long) sits at the right of the brand bar on a phone, and in the masthead's right column from 1024 px.

GEKO can be added to a phone's home screen and opens full screen:

- `public/manifest.json`: name, `display: standalone`, colours, icons. The icons (`public/icon-192.png`, `icon-512.png`, `apple-touch-icon.png`, `favicon.ico`) are placeholders, a gold « G » on the brand green, until there is a logo.
- The layout's `<head>` has the theme colour and the Apple web app tags, with a translucent status bar and `viewport-fit=cover`.
- Content stays clear of the notch and home indicator through the safe-area variables in `studio/_layout.scss`: `--safe-top`, `--safe-right`, `--safe-bottom`, `--safe-left`, and the gutters `--gutter-left` / `--gutter-right`. Anything fixed or sticky to a screen edge must add the matching inset (the nav sticks at `top: var(--safe-top)`).
- An installed app has no browser back button: every page needs a way back (the nav, or `back_link_to`).

## Top nav

Five tabs on every width, icon above label: Dashboard, Clients, Saisir, Mes services, Plus. On a phone the brand bar sits above the tabs and only the tabs stick to the top. From 1024 px the brand bar and the tabs share one sticky bar (`.masthead` in the layout): brand on the left, tabs centred on the page. `nav_tab_to(label, path, section)` renders a tab and marks it active (gold, underlined, `aria-current="page"`) when the page declared that section. « Plus » is a `<details>` menu with no JS. Each item is gated by its policy in the partial: add a page by adding a link inside `if policy(...).action?`, never a role check.

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
| `--badge-chargee-bg` / `-fg` | #1F3A2A / #8FD6A9 | Présent·e |
| `--badge-absence-bg` / `-fg` | #36341A / #F2EC62 | Absence (yellow), wherever an outcome shows |
| `--badge-moins24-bg` / `-fg` | #451616 / #FF6259 | -24h (red), wherever an outcome shows |
| `--badge-planned-bg` / `-fg` | #2A2E3D / #A9B8F0 | Planifié |
| `--badge-warning-bg` / `-fg` | #3D2E1A / #F2B66D | Suspendu, overrun, Mode correction |
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
<span class="badge badge--chargee">Présent·e</span>
<span class="badge badge--absence">Absence</span>
<span class="badge badge--moins24">-24h</span>
<span class="badge badge--overrun">12 mois + 17 j</span>
<span class="badge badge--planned">Planifié</span>
<span class="badge badge--warning">Suspendu</span>
<span class="badge badge--unconfirmed">Non confirmée</span>
<span class="badge badge--retire">Retiré de Fliip</span>
<span class="badge badge--neutral">Toutes les séances utilisées</span>
<span class="text-unconfirmed">Non confirmée</span>
```

The outcome colours mean only the outcome: Présent·e green, Absence yellow, -24h red. The yellow (hue 58) stays apart from the gold accent and from the « Non confirmée » / « à définir » sand (`--badge-unconfirmed`). Service states use their own tokens (`--planned`, `--warning`). `.badge--neutral` is for inactive states and « Toutes les séances utilisées ». `.text-unconfirmed` is the plain-text form.

A service's status badge comes from `service_status_badge(svc)` (`ServiceBadgesHelper`): « Retiré de Fliip » when the service or its client is removed from Fliip, « Toutes les séances utilisées » when a set allocation is used up, else the Fliip status (Actif `--chargee`, Planifié `--planned`, Suspendu `--warning`, others `--neutral`). `contract_status_badge(contract)` does the same for an abonnement.

### Alerts

```erb
<div class="alert alert--moins24" role="alert">
  <%= icon_svg(LayoutHelper::WARNING_ICON, size: 22) %>
  <strong>Aucune absence restante : cette séance sera déduite du forfait (-24h).</strong>
</div>
```

A warning that can't be missed, full width in a status's badge colours (`.alert--moins24`: the -24h colours as background and border), with an icon and bold text. `role="alert"` makes screen readers announce it when it appears; toggle it with `hidden`. For errors use the flash (`.flash--alert`) instead.

### Confirm dialog

A native `<dialog class="dialog">` (`.dialog__title`, `.dialog__body`, `.dialog__actions`) opened with `showModal()`, its buttons as text (`.btn--ghost` to cancel, `.btn--secondary` to go on). `confirm_dialog_controller.js` uses it on Saisir before saving a séance. It asks one question at a time: first when the date is outside the service's dates (« Continuer » / « Annuler »), then when the client is absent (« Confirmer l'absence » / « Revenir »), stating the absence used and how many are left, or that a -24h deducts a séance.

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

Counts edited in bulk (Allocations) use `.cell-input`: a compact 64 px number box with a green border, gold when focused or changed (`.is-changed`), red with `.cell-input--invalid`. A `.suggest` pill next to it is a hint the user clicks to fill the box. See `allocations/_count_input` and `studio/_allocations.scss`.

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

`render "shared/pager", pagy: @pagy` gives page links (‹ 1 … 5 6 7 … 41 ›, from `pager_series`) and a « go to page » box (type a number, press Enter), all keeping the request's other params, such as the search. Put it above the list in a `.list-toolbar` beside the count, and again under the list.

### Client and Service pages

```erb
<div class="page-bar">
  <%= back_link_to "Clients", fliip_users_path %>
  <%= button_to refresh_fliip_user_path(client.remote_id), class: "btn btn--secondary btn--small" do %>…<% end %>
</div>

<ul class="list card-grid">
  <%= render partial: "fliip_services/card", collection: services, as: :service, locals: { show_client: false } %>
</ul>
<p class="empty-state">Aucun service.</p>

<dl class="facts">
  <div><dt>Membre depuis</dt><dd>01/01/2025</dd></div>
  <div class="facts__wide"><dt>Adresse</dt><dd>…</dd></div>
</dl>
```

- `.page-bar`: the back link on the left, a page action on the right (`.btn--small` is a 13 px text button).
- `.client-page`: the top card, then the tabs; from 1024 px the top card is a sticky 360 px column beside them.
- `fliip_services/_card`: a service as a card linking to its Service page (name, `service_status_badge`, dates with the overrun, bars, counts, IDs). `show_client: true` makes the client's name the card's title, with the service name under it (lists scanned by client: Mes services, Échéances); `trainers: [names]` adds an « Entraîneur·e·s : … » line (« — » when the list is empty; leave it out to show no line). A service removed from Fliip shows « historique seulement » and no bars or counts; an allocation not set yet shows « Allocation à définir » and no Séances bar.
- `fliip_services/_bars`: the two thin bars, Temps and Séances, each with its label and percentage above.
- `service_bar(label, percent, colour_class, aside: nil)` (`FliipServicesHelper`) renders one of those bars. With `aside`, the label row reads « Séances · 17 % » on the left and the aside (« 2 / 12 · 10 restantes ») on the right; `.service-bars--detail` makes them thicker (the Service page).
- The Service page: `.service-page__side` holds the top card (`.service-top__*`) and the gold « Saisir une séance » button, or `.service-page__blocked` with `booking_block_reason`, in the `.client-page` left column.
- `sessions/_card` (locals `session:`, `number:`): a séance as a `.seance-card`, « Séance #N », `seance_datetime(time)` (« ven. 13/11/2026 · 17 h 00 »), `duration_short` as its own chip (`.seance-card__duration`, its own column in the desktop row, `.seance-card--timed`), the outcome badge in the outcome's colour (`outcome_badge_class(session)`), reading `session.outcome_label` (Présent·e, Absence or -24h), so there is no separate presence text; trainer, « Saisie par » when someone else entered it, and `confirmation_status(record)` under the created date (« Non confirmée » in `.text-unconfirmed`, or « Confirmée le … » muted, in the same place; works for consultations too). « Modifier » and « Supprimer » sit side by side on a phone and one above the other in the desktop row's last column (`stacked: true`). A note shows only when there is one, as a muted « Note : … » (`.seance-card__note`): a line at the bottom of the card, or, when the row is at least 860 px wide (a container query on `.seance-frame`), its own column between the trainer and the buttons. It's a card on a phone and a row from 1024 px, number and outcome first. `.seance-card--absence` and `.seance-card--moins24` (from `session.outcome`) add a stripe and tint in the badge's colours so exceptions stand out.
- Editing a séance in place: on the Service page each card sits in its own Turbo frame (`sessions/_card_frame`, `dom_id(session)`, `.seance-frame`), and Saisir's rows do the same (`sessions/_recent_frame`). `sessions/_card_actions` shows « Modifier » (`.btn--secondary.btn--small`) and « Supprimer » (`.btn--danger.btn--small`, with `turbo_confirm`) when `policy(session).update?` / `destroy?` allow; pass `context: "saisir"` and `trainer_id:` from Saisir. « Modifier » swaps in `sessions/_edit_card` (`.seance-card.seance-edit`), kept compact in Saisir's row style (`.form-rows` inside the card, packed): date, heure, présence and durée on one line, then the trainer (admins) and the note side by side, by container queries on the card so it fits the Service page and Saisir's side column alike. « Absent·e » takes the Absence colours. Then the same outcome preview as Saisir (`seance_outcome_controller.js` with this séance's usage given back as values) and the same « Confirmer l'absence » dialog (`sessions/_confirm_dialog`) when the edit makes a present séance absent. « Enregistrer » is secondary: the page's gold button stays its main action. `SessionsController` answers saves and deletes with Turbo Streams that replace the Service page's top column (`fliip_services/_summary`, `dom_id(service, :summary)`), its séance list (`fliip_services/_sessions`, `dom_id(service, :sessions)`) and the tab count, or Saisir's `recent_sessions` frame (`bookings/_recent_sessions`).
- `consultations/_card` (locals `consultation:`, `context:` « saisir », « client » or « service »): a consultation on every rebuilt page, in its own Turbo frame (`dom_id(consultation)`, `.seance-frame`), in the séance card's style: the prospect's name with a Présent·e / Absent·e badge, the date and created date with `confirmation_status` under them, the phone (`format_phone`) and email, the trainer, « Saisie par » when someone else entered it, « liée à <service> » (not on the Service page), then « Modifier » and « Supprimer » (with `turbo_confirm`) when the policy allows, and the note only when there is one. An absent prospect gets the Absence stripe. Its layout follows its frame's width (container query, 720 px): stacked in Saisir's side column, a row on the Client and Service pages with the buttons stacked last. Each list item has the id `dom_id(consultation, :item)`, so a delete removes it; on the Client and Service pages the tab count (`dom_id(owner, :consultations_count)`) is refreshed too. « Modifier » swaps in `consultations/_edit_card`, packed like the séance edit card: prénom, nom, courriel and téléphone (`.seance-edit__who`), then date, heure and présence, then the trainer (admins) and a one-line note. `ConsultationsController` answers with Turbo Streams.
- `fliip_contracts/_card` (abonnement).
- `.card-grid`: a list of cards in one column. Service, abonnement and consultation cards are cards on a phone and rows from 1024 px (the service row: title, service and IDs; status; dates; bars and counts), so a list reads like the Clients list on desktop. `.empty-state`: a tab or list with nothing in it.
- `.filter-toggles`: checkbox toggles that filter a list, in a GET form that submits on change (`data-controller="autosubmit"`, `data-action="change->autosubmit#submit"`), each a hand-written `label.checkbox` › `.checkbox__input` + `.checkbox__label`. Put it in the `.list-toolbar` beside the count.

```erb
<%= form_with url: my_services_path, method: :get, class: "filter-toggles",
      data: { controller: "autosubmit", action: "change->autosubmit#submit" } do %>
  <label class="checkbox">
    <%= check_box_tag :inactifs, "1", @show_inactive, class: "checkbox__input" %>
    <span class="checkbox__label">Inactifs</span>
  </label>
<% end %>
```
- `oversight/_session_row` (local `session:`): a séance in « Séances récentes », the whole row a link to its service: `seance_datetime`, the client's name with the service under it, the trainer, the outcome badge with `duration_short`, and `confirmation_status`. A card on a phone (date and outcome, client and service, trainer and confirmation), two cards a row from 768 px; from 1024 px the cards line up in columns under `.recent-seances__head` (subgrid inside `.recent-seances`), like the Clients list. An Absence or a -24h séance gets the same stripe and tint as `.seance-card--absence` / `--moins24`. « Voir plus » under the list is a `.btn--secondary` link to the next page (Pagy countless, no infinite scroll).
- `.facts`: short label-over-value facts in two columns (`.facts--3` for three); `.facts__wide` spans the row.
- Phones always go through `format_phone(raw)` and `phone_href(raw)` (`PhoneHelper`): « (514) 555-0142 », « +33 6 12 34 56 78 », other countries as « +44 7700900123 ». Something that isn't a phone number (« us ») shows as stored, with no link.
- `format_count(1.5)` (`CountsHelper`) shows séance and absence counts: « 1,5 », « 12 », never « 12.0 ».

### Saisir

`bookings/new` (`BookingPage` concern, shared with the create actions that re-render it). The client is a URL param (`new_seance_path(fliip_user_id:, fliip_service_id:)`): the client field (`client_search_controller.js`) fetches `.suggestion` links into the `client_suggestions` frame, and the chosen client shows as a `.chosen-client` card with « Changer ».

- `bookings/_service_option` (`service:`, `checked:`): a service as a `.service-option` radio card (name, séances and absences left, end date, IDs), or `.service-option--blocked` with `booking_block_reason`. One per row on every width (`.service-options`).
- The form column (`.saisir__main`) is the `.form-rows` wrapper (see « Rows: the Saisir variant »). The form: the presence `switch` (Présent·e by default), the services, the trainer (admins), the « Quand » group (Date, Heure and Durée on one row from 768 px) and the note. Its gold button sits in the `.ticket` (« Récapitulatif »: the day, time and duration, client, service, trainer, the outcome badge and its warnings), beside the form from 1024 px and under it on a phone. `form_summary_controller.js` keeps the ticket in step with the form. The consultation tab has the same layout: the prospect (prénom, nom, courriel, téléphone, with « Téléphone ou courriel requis » under them), presence, the trainer (admins), date and heure, and the note; under its ticket, my 10 latest consultations as `consultations/_card` (`context: "saisir"`), editable in place.
- The ticket's outcome: « Enregistrée comme » with the outcome badge and the absence line, then the `.alert--moins24` block. `seance_outcome_preview(session)` (`SessionsHelper`) renders the state on the server and `seance_outcome_controller.js` updates it as the service, presence and duration change.
- `bookings/_recent_session`: a séance in Saisir's side list, in two columns (not `.recent-seance`, which is the Séances récentes page's row). Left: the client's name, the service, `seance_datetime` · `duration_short`, then « Modifier » and « Supprimer ». Right: the outcome badge, then the service's bars (`fliip_services/_bars`, small) with « séances used / allowed · abs. used / allowed » under them (from `FliipService.preload_usage` in `latest_sessions_of`). The name's `.latest-seance__link` covers the card (`::after`); the buttons sit above it. An Absence or a -24h séance takes `seance-card--absence` / `--moins24`. The side list is the trainer's 10 latest séances (the admin's trainer choice, else the signed-in user), never the client's; it is the `recent_sessions` Turbo frame, which `recent_trainer_controller.js` reloads with `?trainer_id=` when an admin changes the trainer. It follows the ticket in the side column (`.saisir__side`).
- `segmented` can take `"1"`/`"0"` values for a boolean; `base_errors(also: [:occurred_at])` adds the full messages of attributes the form has no field for.

### Progress bars

`bar_with_label(percent:, label:, bg_class:)` and the colour helpers in `ProgressHelper` work unchanged; `studio/_progress.scss` styles their class names (`progress`, `progress-bar`, `bg-primary`, `bg-secondary`, `bg-warning`, `bg-orange`, `bg-danger`, `label-dark`, `label-light`).

### Flash

`notice` and `alert` render automatically in the layout. Notices close after 5 s; alerts stay until closed. Use `alert` for errors.

## Forms: StudioFormBuilder

Forms must not look like Bootstrap: no label stacked above an outlined box, no single narrow column on desktop, no full-width bar of a button on desktop. Every form uses the pieces below. `devise/registrations/new.html.erb` is the reference page.

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
- `select_field(attr, choices, label:, hint:, field_class:, include_blank:)`: a `<select>` in the same tile; `choices` is `[[label, value], …]`.
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

### Rows: the Saisir variant

Saisir (`bookings/new`) reads its fields as settings-style rows. Put the page in a `.form-rows` wrapper; the builder's markup is the same, and `studio/_form_rows.scss` restyles it only inside that wrapper. No other form uses it.

- A field is a row: an optional icon (`icon:` on `field`, `select_field` and `segmented`, an SVG path from `LayoutHelper`, such as `CALENDAR_ICON`, `CLOCK_ICON` or `DURATION_ICON`), the label on the left, and the value on the right in bold over a faint rule. The whole row is the click target. A textarea takes the whole row with its label above it.
- A `.form-grid` is the group's card, with a line between rows and a small-caps group title. `.form-grid--single` keeps one column. `.form-grid--when` puts Date, Heure and Durée on one row from 768 px and stacks them on a phone.
- `segmented` is a row with pills on the right, the chosen one gold.
- `switch(attr, choices, label:)`: the large two-option sliding switch, used for presence. It is full width and 58 px tall. The second option is the exception and takes the Absence colours when chosen. A label may carry an icon (`safe_join([ icon_svg(LayoutHelper::CHECK_ICON), "Présent·e" ])`).
- The gold button lives in the page's `.ticket` (`<button form="…">`), not in `.form-actions`.

### Signed-out pages: auth split

Sign in and sign up use `<div class="auth-split">`: a welcome panel (`.auth-split__panel`: `.eyebrow`, `.auth-split__title` as the page's `h1`, `.auth-split__lead`) and the form (`.auth-split__form`). On a phone they stack; from 1024 px the panel is a sticky card in a 300 px column beside the form. The way to the other page is an `.auth-switch` card (a line of context and a `.btn--secondary` link with `button_arrow`) inside `.form-actions`, after the gold button: under it on a phone, on its left from 768 px. A quiet link that belongs to the button (« Mot de passe oublié? » on sign in) goes with it in `.auth-submit`, after it in the HTML so Tab reaches it after the button. A sectioned form can list its parts in the panel with `.form-parts`; the part holding focus lights up gold through `:has` (see `.signup` in `studio/_layout.scss`).

Validation messages are French (`config/locales/fr.yml`); field names come from `activerecord.attributes`. Add a model's attribute names there when its errors show with `full_messages`.
