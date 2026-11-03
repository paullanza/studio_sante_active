# Issue tracker: Linear

Issues and specs for this repo live in Linear, team **Informatique** (key `ENG`). Use the Linear MCP tools (`mcp__claude_ai_Linear__*`) for all operations. If the tools are not connected, stop and ask Paul to reconnect them; don't work from memory or truncated descriptions.

## How the work is organised

- **Project**: one per body of work (e.g. "Codebase Audit & Stabilization", P-ENG-19). Its description covers Goal, Phases, Dependencies and Out of scope, and names the spec document.
- **Spec document**: a Linear document attached to the project (e.g. "Audit & Stabilization Spec"). It is the source of truth for the project's rules and plan. Read it before starting any issue in the project.
- **Milestones**: the project's phases, named with a number (`0. Front-end foundation`, `1. Fliip sync`, ...). Every issue in a project with milestones belongs to one.
- **Issues**: one branch-sized unit of work each. Parent/sub-issue links are not used; ordering comes from `blockedBy` / `blocks`, and `relatedTo` links issues that touch the same area.
- **Project statuses** (French in this workspace): En réserve (idea), À faire (planned), En cours (started), Terminé (done).

## Issue statuses

- **Backlog**: an idea or follow-up, not yet scheduled.
- **Planning**: scoped into a milestone, not started. The default for issues created from a spec.
- **In Progress**: being worked on now.
- **Blocked**: started but waiting on something outside the issue.
- **Done** / **Canceled** / **Duplicate**: closed.

Status must reflect reality. When an issue's original scope is done, close it and open a new issue for the follow-on work.

## Conventions

- **Create an issue**: `save_issue` with `team: "Informatique"`, `assignee: "me"`, a `project`, its `milestone`, a status (usually Planning), and one label from each required group: Domaine, Enjeu, Type, Énergie, Taille. The Triage group is optional (see `triage-labels.md`). Never use the retired groups (Area, Ancien Type). After creating it, say which labels you picked.
- **Before creating one**: search the existing issues for a duplicate, above all in the "Codebase Audit & Stabilization" project. If one already covers it, comment there instead. A bug found while working on something else is noted on the relevant audit issue, not fixed on the spot.
- **Titles**: plain English, sentence case, saying what changes (`Fix the FliipService usage N+1`, `Journey map: home base by role`).
- **Descriptions**: first person, concise but detailed, scoped as one branch of work. Describe only what is done or what is left. The usual shape:
  - an opening line linking it to the spec: `Part of the <Spec name> (see project document).`
  - `##` sections for the problem, the constraints and the approach
  - a closing `## Done when` with the finish line
- **Taille XL** means the issue must be split before it's built (a design issue may be XL on purpose until the design settles).
- **Read an issue**: `get_issue` (with `includeRelations: true` to see blockers). Read it in full before starting work.
- **List issues**: `list_issues`, filtered by team, project, milestone, label or state.
- **Blocking**: `blockedBy` / `blocks` take arrays of issue IDs. `relatedTo` for loose links.
- **Comment**: `save_comment`.
- **Labels**: groups are single-select, so a new label from a group replaces the old one.

## When a skill says "publish a spec" (`/to-spec`)

Write it as a Linear document attached to the relevant project (`save_document`), not as an issue. If the work has no project yet, propose one (name, summary, description, milestones) and confirm with Paul before creating it. Point the project description at the document.

## When a skill says "publish to the issue tracker" (`/to-tickets` and others)

Create Linear issues following **Create an issue** above, in dependency order so blockers exist first, and wire `blockedBy` with the native relation rather than text in the body. Put each issue in the right milestone. Confirm the list with Paul before creating them.

## When a skill says "fetch the relevant ticket"

`get_issue` with the `ENG-xx` identifier.

## How work gets closed

Work closes through git, and Paul merges.

- **Branch**: one per milestone or project (e.g. `feature/audit-phase-1-fliip-sync`). A one-off issue uses its Linear branch name (`feature/eng-xx-<slug>`). Never commit to `main`.
- **Commits**: one per issue. Imperative subject, a prose body explaining what and why, then a line with the `ENG-xx` identifier.
- **PR**: open it once the milestone's issues are done (or as a draft if Paul wants to follow along). The body has a Summary, a commit-by-issue table, a "Things worth a look" or Behaviour changes section where useful, a Merge note asking for **Create a merge commit** or **Rebase and merge** (never Squash), one `Fixes ENG-xx` line per issue, and a Testing section.
- **Never merge.** Merging doesn't move issues to Done in this workspace, so after Paul merges, check the PR is merged and set each issue to Done by hand. Close the milestone's or project's status too when everything in it is done.

## Pull requests as a triage surface

**PRs as a request surface: no.**

## Wayfinding operations

Used by `/wayfinder`. _Not yet used in this repo; confirm the shape with Paul the first time._

- **Map**: an issue whose title starts with `Map:`, in the relevant project and milestone, holding the Notes / Decisions-so-far / Fog body. Its outputs (design notes, decisions) go into the project's spec document.
- **Child ticket**: an issue in the same project and milestone, with Type `Décision`, linked to the map with `relatedTo` and listed in the map body.
- **Blocking**: `blockedBy` on the child. A ticket is unblocked when every blocker is Done or Canceled.
- **Frontier query**: the map's open tickets, minus any with an open blocker or an assignee other than the driver. The first in map order wins.
- **Claim**: set state In Progress, as the session's first write.
- **Resolve**: `save_comment` with the answer, set state Done, then add a pointer (gist + link) to the map's Decisions-so-far.
