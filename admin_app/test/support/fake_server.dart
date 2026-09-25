import 'dart:convert';

import 'package:admin_app/services/api_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A tiny in-memory stand-in for the Laravel admin API, so the real screens
/// and the real [ApiClient] run end to end in widget tests. Anything a test
/// wants to check about what the app asked for is in [requests].
class FakeServer {
  FakeServer({
    List<Map<String, dynamic>>? vehicles,
    Map<int, List<Map<String, dynamic>>>? hires,
    this.canCreateVehicles = true,
    this.canCreateHires = true,
    this.pageSize = 20,
  })  : vehicles = vehicles ?? [],
        hires = hires ?? {};

  final List<Map<String, dynamic>> vehicles;

  /// Hires per vehicle id, each already in the API's JSON shape and already
  /// tagged with a "_tab" the fake serves them under.
  final Map<int, List<Map<String, dynamic>>> hires;

  bool canCreateVehicles;
  bool canCreateHires;
  int pageSize;

  final List<http.Request> requests = [];
  final List<Map<String, dynamic>> createdVehicles = [];
  final List<Map<String, dynamic>> createdHires = [];

  /// When set, every request fails with this HTTP status and message.
  int? failWith;

  Future<void> install() async {
    ApiClient.instance.useHttpClient(MockClient(_handle));

    // Secure storage has no platform side in a widget test; answer "nothing
    // stored" instead of leaving the call hanging.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  }

  List<String> get paths => requests.map((r) => r.url.path).toList();

  Iterable<http.Request> requestsTo(String path) => requests.where((r) => r.url.path == path);

  http.Response _json(Object body, [int status = 200]) => http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json'},
      );

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path.replaceFirst(RegExp(r'^/api'), '');

    if (failWith != null) return _json({'message': 'The server said no.'}, failWith!);

    if (path == '/admin/me') {
      return _json({
        'id': 1,
        'name': 'ZZZ Test Admin',
        'email': 'zzz@example.test',
        'can_create_hires': canCreateHires,
        'can_view_vehicles': true,
        'can_create_vehicles': canCreateVehicles,
      });
    }

    if (path == '/admin/vehicles' && request.method == 'GET') {
      final search = (request.url.queryParameters['search'] ?? '').toLowerCase();
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final matching = vehicles
          .where((v) => search.isEmpty || '${v['model']} ${v['condition']}'.toLowerCase().contains(search))
          .toList();
      final start = (page - 1) * pageSize;
      final slice = matching.skip(start).take(pageSize).toList();
      return _json({
        'data': slice,
        'meta': {'current_page': page, 'last_page': (matching.length / pageSize).ceil().clamp(1, 999)},
        'summary': {
          'vehicle_count': vehicles.length,
          'hire_count': 7,
          'hire_full_value_total': 1250000,
          'our_hire_value_total': 1000000,
          'commission_total': 250000,
        },
      });
    }

    if (path == '/admin/vehicles' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if ((body['model'] as String? ?? '').isEmpty) {
        return _json({'message': 'The model field is required.', 'errors': {'model': ['The model field is required.']}}, 422);
      }
      createdVehicles.add(body);
      final vehicle = {
        'id': 100 + createdVehicles.length,
        ...body,
        'stats': zeroStats(),
      };
      vehicles.add(vehicle);
      return _json({'data': vehicle}, 201);
    }

    final vehicleHires = RegExp(r'^/admin/vehicles/(\d+)/hires$').firstMatch(path);
    if (vehicleHires != null) {
      final id = int.parse(vehicleHires.group(1)!);
      final tab = request.url.queryParameters['tab'] ?? 'all';
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final all = (hires[id] ?? []).where((h) => tab == 'all' || h['_tab'] == tab).toList();
      final start = (page - 1) * pageSize;
      return _json({
        'data': all.skip(start).take(pageSize).map((h) => {...h}..remove('_tab')).toList(),
        'meta': {'current_page': page, 'last_page': (all.length / pageSize).ceil().clamp(1, 999)},
      });
    }

    final vehicleOne = RegExp(r'^/admin/vehicles/(\d+)$').firstMatch(path);
    if (vehicleOne != null) {
      final id = int.parse(vehicleOne.group(1)!);
      final vehicle = vehicles.where((v) => v['id'] == id).firstOrNull;
      if (vehicle == null) return _json({'message': 'Not found.'}, 404);
      return _json({'data': vehicle});
    }

    if (path == '/admin/hires/reference-data') {
      return _json({
        'drivers': [
          {'id': 1, 'name': 'ZZZ Test Driver'},
        ],
        'vehicles': [
          for (final v in vehicles) {'id': v['id'], 'model': v['model']},
        ],
        'customers': [
          {'id': 1, 'name': 'ZZZ Test Customer', 'phone': '0770000000'},
        ],
        'packages': [
          {'id': 1, 'name': 'ZZZ Test Package'},
        ],
      });
    }

    if (path == '/admin/hires' && request.method == 'POST') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      createdHires.add(body);
      final vehicleId = body['vehicle_id'] as int?;
      final startTime = body['start_time'] as String?;
      final hire = hireJson(
        id: 900 + createdHires.length,
        vehicleId: vehicleId,
        startTime: startTime,
        customer: 'ZZZ Test Customer',
        from: body['from_location_name'] as String?,
        to: body['to_location_name'] as String?,
        // A dated-later hire is scheduled; anything else is due today.
        tab: startTime == null ? 'today' : 'scheduled',
      );
      if (vehicleId != null) {
        hires.putIfAbsent(vehicleId, () => []).add(hire);
        final vehicle = vehicles.where((v) => v['id'] == vehicleId).firstOrNull;
        if (vehicle != null) {
          final counts = (vehicle['stats'] as Map<String, dynamic>)['counts'] as Map<String, dynamic>;
          counts['all'] = (counts['all'] as int) + 1;
          counts[hire['_tab']] = (counts[hire['_tab']] as int) + 1;
        }
      }
      return _json({'data': {...hire}..remove('_tab')}, 201);
    }

    final hireOne = RegExp(r'^/admin/hires/(\d+)$').firstMatch(path);
    if (hireOne != null) {
      final id = int.parse(hireOne.group(1)!);
      for (final list in hires.values) {
        final found = list.where((h) => h['id'] == id).firstOrNull;
        if (found != null) return _json({'data': {...found}..remove('_tab')});
      }
      return _json({'message': 'Not found.'}, 404);
    }

    return _json({'message': 'Unexpected request: ${request.method} $path'}, 500);
  }
}

Map<String, dynamic> zeroStats() => vehicleStatsJson();

Map<String, dynamic> vehicleStatsJson({
  int hireCount = 0,
  num full = 0,
  num our = 0,
  int monthCount = 0,
  num monthFull = 0,
  int all = 0,
  int today = 0,
  int scheduled = 0,
  int completed = 0,
  int cancelled = 0,
  int running = 0,
}) =>
    {
      'hire_count': hireCount,
      'hire_full_value_total': full,
      'our_hire_value_total': our,
      'commission_total': full - our,
      'month': {'hire_count': monthCount, 'hire_full_value_total': monthFull, 'commission_total': 0},
      'counts': {
        'all': all,
        'today': today,
        'scheduled': scheduled,
        'completed': completed,
        'cancelled': cancelled,
        'running': running,
      },
    };

Map<String, dynamic> vehicleJson({
  required int id,
  String model = 'ZZZ Test Van',
  String condition = 'Good',
  int seats = 4,
  int pax = 4,
  String? description,
  Map<String, dynamic>? stats,
}) =>
    {
      'id': id,
      'model': model,
      'condition': condition,
      'seats': seats,
      'pax': pax,
      'description': description,
      'stats': stats ?? zeroStats(),
    };

/// A hire in the API's shape. [tab] is the fake's own routing tag.
Map<String, dynamic> hireJson({
  required int id,
  int? vehicleId,
  String tab = 'today',
  String customer = 'ZZZ Test Customer',
  String status = 'pending',
  String? startTime,
  String? from = 'ZZZ From',
  String? to = 'ZZZ To',
  String? driver,
  String? cancelReason,
  num full = 1000,
}) =>
    {
      '_tab': tab,
      'id': id,
      'tour_type': 'drop_pickup',
      'tour_type_label': 'Drop and Pickup',
      'status': status,
      'status_label': switch (status) {
        'started' => 'Driver Hire Started',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => 'Pending',
      },
      'is_upcoming': false,
      'start_time': startTime,
      'end_time': null,
      'from_location': from,
      'to_location': to,
      'stay_locations': [],
      'day_locations': [],
      'package': null,
      'hire_full_value': full,
      'our_hire_value': full * 0.8,
      'commission': full * 0.2,
      'payment_type': 'cash',
      'payment_type_label': 'Cash',
      'paid_amount': 0,
      'balance_remaining': full,
      'payment_status': 'unpaid',
      'customer': {'id': 1, 'name': customer, 'phone': '0770000000'},
      'driver': driver == null ? null : {'id': 1, 'name': driver},
      'vehicle': vehicleId == null ? null : {'id': vehicleId, 'model': 'ZZZ Test Van'},
      'description': null,
      'is_tracking': false,
      'total_distance_km': 0,
      'cancelled_at': null,
      'cancel_reason': cancelReason,
      'created_at': null,
    };
