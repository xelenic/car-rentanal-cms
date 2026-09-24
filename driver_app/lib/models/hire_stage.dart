import 'hire.dart';

/// Where a hire is in the driver's flow — decides which buttons the hire
/// screen offers:
///
///  * [pickup]     — nothing done yet: a single "Pickup" button.
///  * [start]      — picked up (or tracking was paused): the "Start" button.
///  * [inProgress] — tracking: "Stop" and "Complete".
///  * [completed]  — finished.
enum HireStage { pickup, start, inProgress, completed }

/// [pickedUp] is the driver's own "I'm on my way to the pickup" mark for this
/// hire (see PickupStore). A hire that was already started once and then
/// stopped counts as picked up too, so pausing never sends the driver back to
/// the Pickup button.
HireStage hireStageOf(Hire hire, {required bool pickedUp}) {
  if (hire.isCompleted) return HireStage.completed;
  if (hire.isTracking) return HireStage.inProgress;
  if (pickedUp || hire.trackingStartedAt != null) return HireStage.start;
  return HireStage.pickup;
}
