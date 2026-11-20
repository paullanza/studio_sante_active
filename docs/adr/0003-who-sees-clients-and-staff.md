# 3. Every client is visible to every role; managers see every staff member but the super admin

Status: accepted (2026-11-15)

Every signed-in user, employees included, can see every client and their services. The studio works as one team: any trainer can take any client's séance, and staff need to look clients up without asking for access. Dashboards may highlight a user's own clients, but lists and search always show everyone. Don't scope clients or services by role or by "my clients"; this has been decided more than once.

Managers can see every staff member's page except the super admin's, admins included, because admins have clients too and a manager needs to check on those clients' progress (2026-11-16). Seeing isn't acting: a manager can still only change role or active status for employees (`UserPolicy`).

## Considered options

- **Scope clients by trainer.** Rejected: clients move between trainers, and a trainer covering a séance would lose access to the client in front of them.
- **Managers see employees only.** Rejected: it hides admins' clients from the people who follow up on them.
