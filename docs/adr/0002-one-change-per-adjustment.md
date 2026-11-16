# 2. One change per adjustment, old adjustments split

Status: accepted (2026-11-15)

Adjustments began as a bulk-import tool: when the app started tracking séances, 250+ clients were mid-service, and each one got a single row holding three numbers (séances used, absences used, extra séances). Today adjustments are used to grant extra séances or absences, and each one needs a trainer, a creator and a note. We decided that every adjustment holds exactly one change of one kind, and that a data migration splits the old three-number rows into single-change rows (with their original creator and date and the note « Import initial »), rather than keeping two row shapes forever. The migration compares every service's used and allowed totals before and after, and aborts on any difference.

## Considered options

- **Keep old rows as they are.** No production data would change, but every reader of adjustments would have to handle two shapes indefinitely.
