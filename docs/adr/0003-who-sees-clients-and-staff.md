# 3. Every client is visible to every role; managers see every staff member but the super admin

Status: accepted (2026-11-15)

Every signed-in user, employees included, can see every client and their services. Dashboards may highlight a user's own clients, but lists and search always show everyone. Don't scope clients or services by role or by "my clients": this has been decided more than once and isn't open for re-discussion.

Managers can see every staff member's page except the super admin's, admins included, because admins have clients too and a manager needs to check on those clients' progress (2026-11-16). Seeing isn't acting: a manager can still only change role or active status for employees (`UserPolicy`).
