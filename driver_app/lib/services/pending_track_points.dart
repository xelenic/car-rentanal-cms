import 'dart:convert';

import '../models/tracking_status.dart';

/// A fix younger than this is sent without a timestamp, so the server stamps
/// it on arrival — the phone's clock can be wrong, the server's isn't. Older
/// ones (queued while offline) carry their own time so they land in the right
/// place on the path.
const Duration kFreshFixAge = Duration(seconds: 45);

/// One GPS fix read by the background service that hasn't reached the server
/// yet.
class PendingTrackPoint {
  final int hireId;
  final double latitude;
  final double longitude;

  /// When the phone took the fix (UTC).
  final DateTime capturedAt;

  const PendingTrackPoint({
    required this.hireId,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  /// The time to report to the server, or null when the fix is fresh enough
  /// to let the server use its own clock (see [kFreshFixAge]).
  DateTime? recordedAtFor(DateTime now) =>
      now.difference(capturedAt) > kFreshFixAge ? capturedAt : null;

  Map<String, dynamic> toJson() => {
        'h': hireId,
        'lat': latitude,
        'lng': longitude,
        'at': capturedAt.toUtc().toIso8601String(),
      };

  static PendingTrackPoint? tryParse(Object? json) {
    if (json is! Map) return null;

    final hireId = json['h'];
    final lat = json['lat'];
    final lng = json['lng'];
    final at = json['at'] is String ? DateTime.tryParse(json['at'] as String) : null;
    if (hireId is! num || lat is! num || lng is! num || at == null) return null;

    return PendingTrackPoint(
      hireId: hireId.toInt(),
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      capturedAt: at.toUtc(),
    );
  }
}

/// The background service's send queue. Every fix goes in here first and only
/// leaves once the server has accepted it, so a stretch without signal (or a
/// server hiccup) leaves a gap of *delay*, not a gap in the path — the queued
/// points are sent, oldest first, as soon as the connection is back.
///
/// It's saved to disk between ticks (see [encode]/[decode]) so points also
/// survive the OS killing the service mid-request.
class PendingTrackPoints {
  /// About six hours of fixes at one every 15 seconds; beyond that the oldest
  /// are dropped rather than letting the saved queue grow without limit.
  static const int maxPoints = 1500;

  final List<PendingTrackPoint> _points;

  PendingTrackPoints([Iterable<PendingTrackPoint> points = const []]) : _points = points.toList() {
    _trim();
  }

  /// Restores a queue saved by [encode]; anything unreadable yields an empty
  /// queue rather than an error, since a corrupt save must never stop tracking.
  factory PendingTrackPoints.decode(String? raw) {
    if (raw == null || raw.isEmpty) return PendingTrackPoints();

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return PendingTrackPoints();
      return PendingTrackPoints(decoded.map(PendingTrackPoint.tryParse).whereType<PendingTrackPoint>());
    } catch (_) {
      return PendingTrackPoints();
    }
  }

  String encode() => _points.isEmpty ? '' : jsonEncode(_points.map((p) => p.toJson()).toList());

  int get length => _points.length;
  bool get isEmpty => _points.isEmpty;

  int countForHire(int hireId) => _points.where((p) => p.hireId == hireId).length;

  void add(PendingTrackPoint point) {
    _points.add(point);
    _trim();
  }

  /// Forgets points for hires that are no longer being tracked.
  void retainHires(Set<int> hireIds) => _points.removeWhere((p) => !hireIds.contains(p.hireId));

  void removeHire(int hireId) => _points.removeWhere((p) => p.hireId == hireId);

  /// Sends up to [limit] of [hireId]'s queued points, oldest first, through
  /// [send], dropping each from the queue once [send] returns. The first
  /// failure is rethrown and everything not yet sent stays queued, in order.
  /// Returns the status from the last accepted point (null if nothing was
  /// queued).
  Future<TrackingStatus?> flushHire(
    int hireId,
    Future<TrackingStatus> Function(PendingTrackPoint point) send, {
    int limit = 10,
  }) async {
    TrackingStatus? latest;
    var sent = 0;

    for (final point in _points.where((p) => p.hireId == hireId).toList()) {
      if (sent >= limit) break;

      latest = await send(point);
      _points.remove(point);
      sent++;
    }

    return latest;
  }

  void _trim() {
    if (_points.length > maxPoints) {
      _points.removeRange(0, _points.length - maxPoints);
    }
  }
}
