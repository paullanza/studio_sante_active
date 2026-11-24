# Allocations the Fliip sync created as 0/0 were never set by an admin.
# They become « à définir » (nil/nil) once, so each gets a real look.
# Small table (one row per kind of service): no lock concern, reversible.
class MarkZeroAllocationsToDefine < ActiveRecord::Migration[8.1]
  class MigrationServiceDefinition < ActiveRecord::Base
    self.table_name = "service_definitions"
  end

  def up
    count = MigrationServiceDefinition.where(paid_sessions: 0, free_sessions: 0)
                                      .update_all(paid_sessions: nil, free_sessions: nil)
    say "#{count} allocation(s) 0/0 marquée(s) à définir"
  end

  def down
    paid = MigrationServiceDefinition.where(paid_sessions: nil).update_all(paid_sessions: 0)
    free = MigrationServiceDefinition.where(free_sessions: nil).update_all(free_sessions: 0)
    say "#{paid} séances et #{free} absences à définir remises à 0"
  end
end
