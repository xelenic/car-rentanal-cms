// Runs only on the web platform:  flutter test --platform chrome test/route_planner_web_test.dart
//
// The app is also built for the web (the local preview), where Dart integers
// are JavaScript numbers and bitwise operators behave differently from the
// Dart VM: `~x` there returns an unsigned 32-bit value. The polyline decoder
// once used `~` for negative deltas and passed every VM test while drawing
// garbage points in the browser — this keeps that from coming back.
@TestOn('browser')
library;

import 'package:driver_app/services/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

void main() {
  test('decodes Google\'s documented example, negative coordinates included, on the web', () {
    expect(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), [
      const LatLng(38.5, -120.2),
      const LatLng(40.7, -120.95),
      const LatLng(43.252, -126.453),
    ]);
  });

  test('a route that moves south and west (negative deltas) stays where it should', () {
    // Colombo → Galle direction: latitude and longitude both fall along the way
    final points = decodePolyline(_encode([(6.93344, 79.84278), (6.58540, 79.96070), (6.05364, 80.22120)]));

    expect(points.map((p) => p.latitude), [6.93344, 6.5854, 6.05364]);
    expect(points.map((p) => p.longitude), [79.84278, 79.9607, 80.2212]);
  });
}

/// Google's polyline encoder (test-only) — written with arithmetic instead of bit tricks.
String _encode(List<(double, double)> points) {
  final out = StringBuffer();
  var prevLat = 0, prevLng = 0;

  void write(int delta) {
    var value = delta < 0 ? (-delta) * 2 - 1 : delta * 2;
    while (value >= 32) {
      out.writeCharCode(((value % 32) + 32) + 63);
      value ~/= 32;
    }
    out.writeCharCode(value + 63);
  }

  for (final (lat, lng) in points) {
    final latE5 = (lat * 1e5).round(), lngE5 = (lng * 1e5).round();
    write(latE5 - prevLat);
    write(lngE5 - prevLng);
    prevLat = latE5;
    prevLng = lngE5;
  }
  return out.toString();
}
