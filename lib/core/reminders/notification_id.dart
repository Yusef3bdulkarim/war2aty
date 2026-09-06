/// A stable, non-negative 31-bit id derived from [alertId], for the
/// `flutter_local_notifications` API — which wants a small `int` it can be
/// told to cancel later, not a UUID.
///
/// Deterministic on purpose: cancelling or rescheduling an alert only ever
/// needs its own [alertId], recomputed the same way it was scheduled —
/// nothing has to look the int up and store it separately. It is also stored
/// alongside the alert (`ReminderAlerts.notificationId`) so a reconcile pass
/// (F09-T13) can cancel by the id the OS actually has, even if this function
/// ever changed.
///
/// Collisions are possible in principle — many different alert ids can hash
/// to the same 31-bit int — but for the handful of reminders one person
/// keeps at once, in practice they don't happen, and a collision would only
/// ever cost a duplicate/overwritten local notification rather than data
/// loss (the database row is unaffected either way).
int notificationIdOf(String alertId) => alertId.hashCode & 0x7fffffff;
