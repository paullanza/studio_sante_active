# 1. Fliip sync: four jobs, flag instead of delete

Status: accepted (2026-11-03)

## Context

Clients, services and contracts are mirrored from Fliip. The old sync was brittle: every API error became an empty list, it made redundant calls, it never noticed records deleted in Fliip, and the only full sync ran in one long pass.

What the API allows (details in `docs/fliip_api/README.md`): services and contracts can only be fetched one user at a time; there is no reliable change feed (`/gate/getChangedUsers` misses users without a contract and never reports deletions); `user_status` doesn't reflect reality; `/users/get` is sorted newest first. We confirmed this with a read-only walk of every user in Fliip plus probes of the gate endpoints.

## Decision

Rewrite the sync from scratch against the current schema, with four jobs that share one pipeline (fetch, map, upsert, flag) and differ only in which users they cover:

| Job | Users | Runs |
|---|---|---|
| Single user | One `FliipUser` | On demand, in the web request |
| New clients | Users newer than the newest local one (first page of `/users/get`) | On demand, in the web request (the booking page's "refresh clients") |
| Recent | New clients, plus users with a service or contract that ended in the last 30 days | Hourly background job |
| Full | Everyone | Nightly background job (midnight); also enqueued by the admin "import clients" button |

- Background jobs run in the app: Solid Queue inside Puma, in async mode (threads, not forked processes) to fit the web instance's memory. There is no separate cron service. If memory gets tight, the scheduled jobs can move to a separate service without code changes.
- Per user: 1 call for services (`get_history`) and 3 for contracts.
- A failed call raises. It never looks like "no data". If the user list fails, the run stops; if one user fails, that user is skipped and nothing of theirs is flagged.
- Records Fliip no longer returns are flagged, never deleted, and a flagged service can't be booked. A record that comes back is unflagged.
- `/gate/getChangedUsers` isn't used.
- No sync run log is kept. A job with failed users raises at the end, so admins see the failure in Mission Control (`mission_control-jobs` at `/jobs`).

## Consequences

- A purchase is picked up within the hour, or immediately with a single-user refresh.
- Deletions are noticed on the next run that covers that user.
- Service definitions stay manual: Fliip gives the service name but not the paid or free session allowance.
