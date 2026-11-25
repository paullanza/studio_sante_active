# Studio Santé Active

The staff app where trainers log séances and consultations against the services clients bought in Fliip, and admins confirm that work for payroll.

UI terms are French, code terms are English. Entries give both where they differ.

## People

**Staff member** (« membre du personnel », the group is « personnel »):
Someone with an account in this app. Their role (employee, manager, admin or super admin) decides what they can do.
_Avoid_: User (on its own), « employé » (that's one role)

**Client** (« client »):
Anyone in Fliip who can hold services. Fliip staff who buy services are clients too, and they aren't separated from other clients.
_Avoid_: Member, customer, Fliip user (in the UI)

## Fliip data

**Service** (« service »):
A package a client bought in Fliip, with start and expiry dates. Séances are booked against it.
_Avoid_: Forfait, package, purchase

**Allocation** (`ServiceDefinition` in code):
The number of séances and absences allowed for one kind of service. Admins set it by hand because Fliip doesn't provide it.
_Avoid_: Service definition, service type (in the UI)

**Abonnement** (`FliipContract` in code):
A client's gym membership in Fliip, giving access to the gym and group classes. The app only keeps it for reference: nothing is booked or counted against it.
_Avoid_: Contract (in the UI), subscription

**Removed from Fliip** (« Retiré de Fliip »):
A client or service that Fliip no longer returns. It is kept with its history but can't be booked.
_Avoid_: Deleted, archived

## Séances

**Séance** (`Session` in code):
One booked slot where a staff member trains a client, logged against one of the client's services. It lasts 1 h or 30 min, and a 30 min séance counts as half.
_Avoid_: Session (in the UI), booking, appointment

**Semi-privé**:
A séance time shared by 2 to 4 clients. It counts as one séance for each client.
_Avoid_: Group séance, duo

**Présent·e** (outcome):
A séance where the client was present. It uses one of the service's séances. The code calls this outcome `chargee`.
_Avoid_: Chargée, paid session (in the UI)

**Absence**:
A séance where the client was absent and the service still had an absence left. It uses an absence, not a séance.
_Avoid_: Free session, no-show

**-24h**:
A séance where the client was absent and the service had no absences left, so it uses a séance instead. Cancellations made more than 24 hours ahead are not logged.
_Avoid_: Late cancellation, charged absence

**Presence** (« présent » / « absent »):
Whether the client or prospect showed up. It is always logged, on séances and consultations alike.

**Overrun** (« dépassement », shown as « 12 mois + 17 j »):
The number of days a service's end date runs past its planned end: the start date plus the planned length in months, from Fliip's duration (« 12 Mois ») or, when Fliip says « Indéfini », from « N mois » in the service name. Up to 2 days past is how the calendar falls and isn't an overrun.
_Avoid_: Extension, overtime

**Complete service** (« Toutes les séances utilisées »):
A service with no séances left. It can't be booked, even if it still has absences, because an absence can never stand in for a séance.
_Avoid_: Expired, finished (those are about dates)

**Adjustment** (« ajustement », `ServiceUsageAdjustment` in code):
A manual change to one service's counts: séances or absences granted beyond the allocation, or usage recorded without logging séances one by one.
_Avoid_: Correction, bonus, override

## Consultations

**Prospect** (« prospect »):
Someone who isn't a client yet. Their details are typed into the consultation by hand, with a phone or an email to reach them.
_Avoid_: Lead, client (until they buy)

**Consultation**:
A meeting between a staff member and a prospect. The staff member is paid for it as for a séance, whether the prospect was present or absent. It never uses a service's séances or absences.
_Avoid_: Trial, evaluation

**Linked consultation**:
A consultation attached to the service the prospect bought afterwards. A consultation links to at most one service, and a service can have several consultations, for example when the prospect missed the first one.
_Avoid_: Converted consultation, associated consultation

**No purchase** (« Aucun achat »):
The follow-up outcome of a consultation that ended without a sale. It can be set whether or not a client is linked, and it can be undone.
_Avoid_: Lost, rejected, closed

## Payroll

**Signature sheet** (« feuille de signatures »):
The paper a client signs when present at a séance. It is the studio's proof of attendance if an employee or a client ever disputes one.

**Confirmed** (« confirmé »):
A séance or consultation an admin has checked against the signature sheet and approved for payroll. Only admins can change it once it's confirmed.
_Avoid_: Approved, validated, paid

**Pay period** (« période de paie »):
A two-week cycle, Sunday to Saturday inclusive, that staff are paid on.
_Avoid_: Pay cycle, week
