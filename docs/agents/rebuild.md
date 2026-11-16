# Rebuilding a page (Total Restructure)

Rules for every issue in the Linear project Total Restructure. The issue's own Agent notes say what to build; this file says how. `CLAUDE.md` still applies in full.

## Before you start

- Read `CLAUDE.md`, `GLOSSARY.md`, `docs/ui.md` (once it exists) and the issue, including what blocks it. Don't start an issue whose blockers aren't merged.
- Use the terms in `GLOSSARY.md`, in code comments and in UI copy alike.
- Mockups live in `docs/design/` (inline-styled HTML). When an issue names one, match its structure, order and wording. When none exists, build from `docs/ui.md` components and the layout the issue describes.
- Work in your own worktree on the branch name Linear gives the issue: `git worktree add ../studio_sante_active-eng-NNN -b <branch> origin/main`.

## How a rebuilt page ships

- One issue, one branch, one PR. The PR body starts with `Closes ENG-NNN`.
- The new page replaces the old one in the same PR: the controller switches to `layout "studio"`, and the old view, partials, Stimulus controllers, helpers and Sass that only that page used are deleted. Grep before deleting; something still in use stays.
- Keep routes and route helper names unless the issue says to change them, so links from pages not yet rebuilt keep working.
- No Bootstrap classes, no simple_form, no inline styles and no raw hex on a rebuilt page. If `docs/ui.md` is missing a component the page needs, add it to the `studio/` stylesheets and to `docs/ui.md` in the same PR.
- UI copy is French. Dates show as `dd/mm/yyyy`, times as `HH:MM`.
- Mobile first: build for 375 px, then check 768 px and desktop.

## Authorization

- Every action calls `authorize` or `policy_scope`, or `skip_authorization` with a reason.
- Role checks go in policies, never in controllers or views.
- Every client is visible to every role. Don't scope clients or services by role.

## Specs

- Every new controller action has request specs, every policy change has policy specs, every new model method has model specs, in the same PR.
- Update `spec/requests/role_access_spec.rb` whenever a route or its access changes.
- Delete the specs of deleted code. Don't weaken a spec that still describes kept behaviour.
- Never call the Fliip API; stub `FliipApi::Client` or `FliipApi::UserSyncer`.
- Pin time with `travel_to` before creating records that depend on dates (`before` above any `let!`).
- Stimulus is not specced. Say in the PR what you checked by hand in the browser.

## Database

- Schema changes follow `CLAUDE.md` « Schema changes ». Data migrations use local `Migration*` classes.
- Say in the PR if a migration locks a large table or can't be rolled back.

## Before opening the PR

- `bundle exec rspec`, `bundle exec rubocop`, `bundle exec brakeman -q` all pass.
- Check the page in a browser at 375 px and on desktop, for each role the issue names.
- Stage explicit paths only (never `git add -A`), push, open the PR. Never merge it.
