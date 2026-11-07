import 'package:network_protocol/job_lifecycle_protocol.dart';

// ============================================
// SCS JOB LIFECYCLE TRACKER
// ============================================

/// Detects changes in the SCS SDK's
/// revision-12 job state and toggle flags.
///
/// Important:
/// jobDelivered and jobCancelled are NOT
/// ordinary persistent state flags.
///
/// The plugin toggles their values each time
/// a corresponding gameplay event occurs.
class ScsJobLifecycleTracker {
  bool _initialized = false;

  int? _previousGameId;

  bool _previousOnJob = false;
  bool _previousDelivered = false;
  bool _previousCancelled = false;

  // ==========================================
  // RESET
  // ==========================================

  /// Reset when shared memory disappears or
  /// the game SDK is restarted.
  ///
  /// The next observation establishes a
  /// baseline and emits no event.
  void reset() {
    _initialized = false;
    _previousGameId = null;
    _previousOnJob = false;
    _previousDelivered = false;
    _previousCancelled = false;
  }

  // ==========================================
  // OBSERVE CURRENT MEMORY VALUES
  // ==========================================

  JobLifecycleEventKind? observe({
    required int gameId,
    required bool onJob,
    required bool deliveredFlag,
    required bool cancelledFlag,
  }) {
    // Ignore invalid/unidentified games.
    if (gameId != 1 && gameId != 2) {
      reset();
      return null;
    }

    // ========================================
    // INITIAL OBSERVATION / GAME SWITCH
    // ========================================

    if (!_initialized || _previousGameId != gameId) {
      _initialized = true;

      _previousGameId = gameId;
      _previousOnJob = onJob;
      _previousDelivered = deliveredFlag;
      _previousCancelled = cancelledFlag;

      // Do not replay old events after
      // starting TruckLink Hub.
      return null;
    }

    // ========================================
    // DETECT CHANGES
    // ========================================

    final wasOnJob = _previousOnJob;

    final deliveredChanged = deliveredFlag != _previousDelivered;

    final cancelledChanged = cancelledFlag != _previousCancelled;

    // Update the baseline immediately.
    // Every next poll compares against it.
    _previousOnJob = onJob;
    _previousDelivered = deliveredFlag;
    _previousCancelled = cancelledFlag;

    // ========================================
    // CLASSIFY TERMINAL EVENT
    // ========================================

    if (deliveredChanged && !cancelledChanged) {
      return JobLifecycleEventKind.delivered;
    }

    if (cancelledChanged && !deliveredChanged) {
      return JobLifecycleEventKind.cancelled;
    }

    // Both toggles changed between polls.
    // Do not guess which event happened last.
    if (deliveredChanged && cancelledChanged) {
      return null;
    }

    // ========================================
    // NEW JOB
    // ========================================

    if (!wasOnJob && onJob) {
      return JobLifecycleEventKind.started;
    }

    // The job can also disappear without
    // a confirmed delivered/cancelled event,
    // e.g. due to profile switching.
    //
    // In that situation, do NOT invent
    // a successful delivery.
    return null;
  }
}
