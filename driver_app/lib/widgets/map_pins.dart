import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/map_role.dart';
import '../theme/app_theme.dart';

/// The colour of a place's marker and of its entry in the legend.
Color mapRoleColor(MapRole role) {
  switch (role) {
    case MapRole.pickup:
      return const Color(0xFF16A34A); // green — where to collect the customer
    case MapRole.end:
      return AppColors.danger; // red — where the trip ends
    case MapRole.stop:
      return AppColors.warning; // amber — anything in between
    case MapRole.single:
      return const Color(0xFF7C3AED); // violet — a lone place
  }
}

/// The map's own pin pictures — a coloured teardrop with a letter: P pickup,
/// E end, S stop, a dot for a lone place. Drawn here rather than using the
/// map's built-in hue-tinted markers because the web map ignores those (every
/// pin would come out red); pictures look the same on every platform, and the
/// letter means the pin is readable without knowing the colour code.
class MapPins {
  MapPins._();

  static const double _width = 36;
  static const double _height = 46;
  static const double _scale = 3; // drawn at 3x so pins stay sharp on dense screens

  static final Map<MapRole, Future<BitmapDescriptor>> _cache = {};

  /// Drawn once per role, then reused.
  static Future<BitmapDescriptor> forRole(MapRole role) => _cache.putIfAbsent(role, () => _draw(role));

  static Future<BitmapDescriptor>? _you;

  /// The driver's own position: a blue dot with a white ring and a soft halo.
  static Future<BitmapDescriptor> you() => _you ??= _drawYou();

  static Future<BitmapDescriptor> _drawYou() async {
    const size = 36.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    const centre = Offset(size / 2, size / 2);

    canvas.drawCircle(centre, 16, Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.22));
    canvas.drawCircle(centre, 9.5, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 7, Paint()..color = const Color(0xFF2563EB));

    final image = await recorder.endRecording().toImage((size * _scale).round(), (size * _scale).round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: size, height: size);
  }

  static String _letter(MapRole role) {
    switch (role) {
      case MapRole.pickup:
        return 'P';
      case MapRole.end:
        return 'E';
      case MapRole.stop:
        return 'S';
      case MapRole.single:
        return '';
    }
  }

  static Future<BitmapDescriptor> _draw(MapRole role) async {
    final color = mapRoleColor(role);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);

    const centre = Offset(_width / 2, _width / 2);
    const radius = _width / 2 - 2;

    // teardrop: a circle whose bottom narrows to a point at the very bottom
    final pin = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: radius))
      ..moveTo(centre.dx - radius * 0.62, centre.dy + radius * 0.78)
      ..lineTo(centre.dx, _height - 1)
      ..lineTo(centre.dx + radius * 0.62, centre.dy + radius * 0.78)
      ..close();

    canvas.drawShadow(pin, Colors.black.withValues(alpha: 0.6), 2, true);
    canvas.drawPath(pin, Paint()..color = color);
    canvas.drawPath(
      pin,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(centre, radius * 0.62, Paint()..color = Colors.white);

    final letter = _letter(role);
    if (letter.isEmpty) {
      canvas.drawCircle(centre, radius * 0.28, Paint()..color = color);
    } else {
      final text = TextPainter(
        text: TextSpan(text: letter, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, centre - Offset(text.width / 2, text.height / 2));
    }

    final image = await recorder.endRecording().toImage((_width * _scale).round(), (_height * _scale).round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), width: _width, height: _height);
  }
}
