# Triage Labels

The skills speak in terms of five canonical triage roles. This file maps those roles to the actual label strings used in this repo's issue tracker.

| Label in mattpocock/skills | Label in our tracker | Meaning                                  |
| -------------------------- | -------------------- | ---------------------------------------- |
| `needs-triage`             | `needs-triage`       | Maintainer needs to evaluate this issue  |
| `needs-info`               | `needs-info`         | Waiting on reporter for more information |
| `ready-for-agent`          | `ready-for-agent`    | Fully specified, ready for an AFK agent  |
| `ready-for-human`          | `ready-for-human`    | Requires human implementation            |
| `wontfix`                  | `wontfix`            | Will not be actioned                     |

When a skill mentions a role (e.g. "apply the AFK-ready triage label"), use the corresponding label string from this table.

These live in Linear as the single-select label group **Triage** (team Informatique). The group is optional: only issues that go through `/triage` carry one.

Triage labels sit alongside the issue status, which still has to match:

- `needs-triage` and `needs-info`: status Backlog.
- `ready-for-agent` and `ready-for-human`: status Planning, in a project milestone, with all the required label groups set.
- `wontfix`: status Canceled, with a comment saying why.

Edit the "Label in our tracker" column to match whatever vocabulary you actually use.
