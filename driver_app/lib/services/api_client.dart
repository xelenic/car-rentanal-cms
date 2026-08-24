import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/available_periods.dart';
import '../models/driver.dart';
import '../models/driver_deposit_transfer.dart';
import '../models/driver_salary.dart';
import '../models/hire_expense.dart';
import '../models/hire_page.dart';
import '../models/salary_advance_request.dart';
import '../models/tracking_status.dart';
import '../models/vehicle.dart';
import '../models/vehicle_maintenance_record.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  /// Base URL of the Car Rental CMS API.
  ///
  /// Exported/production builds bake in the real server via
  /// --dart-define=API_BASE_URL=https://xnatureland1.xelenic.com/api (see
  /// the export build command) — that always wins when present. Without
  /// it (plain `flutter run` during development) this falls back to local
  /// dev defaults:
  /// - Android emulator: 10.0.2.2 aliases the host machine's localhost —
  ///   the emulator is its own machine, so plain "localhost" here would
  ///   mean the emulator itself, not the host running the Laravel server.
  /// - Web / iOS simulator / desktop: localhost reaches the host directly.
  /// - Physical device during dev: replace with your computer's LAN IP,
  ///   e.g. http://192.168.1.20:8000/api
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'driver_app_token';

  String? _cachedToken;

  Future<String?> get _token async {
    _cachedToken ??= await _storage.read(key: _tokenKey);
    return _cachedToken;
  }

  Future<bool> get isLoggedIn async => (await _token) != null;

  Future<Map<String, String>> _headers({bool auth = false}) async {
    final headers = {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final token = await _token;
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<Driver> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String;
      _cachedToken = token;
      await _storage.write(key: _tokenKey, value: token);
      return Driver.fromJson(data['driver'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<void> logout() async {
    try {
      await http.post(
        Uri.parse('$baseUrl/auth/logout'),
        headers: await _headers(auth: true),
      );
    } finally {
      _cachedToken = null;
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<Driver> fetchMe() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/me'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Driver.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<HirePage> fetchHires({int? year, int? month}) async {
    final uri = Uri.parse('$baseUrl/driver/hires').replace(
      queryParameters: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return HirePage.fromJson(data);
    }

    throw ApiException(_extractError(response));
  }

  Future<AvailablePeriods> fetchAvailablePeriods() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/hires/periods'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return AvailablePeriods.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<DriverSalary> fetchSalary({int? year, int? month}) async {
    final uri = Uri.parse('$baseUrl/driver/salary').replace(
      queryParameters: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return DriverSalary.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<List<SalaryAdvanceRequest>> fetchSalaryAdvances() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/salary-advances'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => SalaryAdvanceRequest.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  /// All of the driver's arrears loans (converted deficits from a negative
  /// Net Payment), each with its full month-by-month deduction schedule —
  /// not scoped to a single salary period.
  Future<List<ArrearsLoan>> fetchArrearsLoans() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/arrears-loans'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => ArrearsLoan.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<SalaryAdvanceRequest> requestSalaryAdvance({
    required double amount,
    String? reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/salary-advances'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'amount': amount,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return SalaryAdvanceRequest.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<List<DriverDepositTransfer>> fetchDepositTransfers({int? year, int? month}) async {
    final uri = Uri.parse('$baseUrl/driver/deposit-transfers').replace(
      queryParameters: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
      },
    );
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => DriverDepositTransfer.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<DriverDepositTransfer> addDepositTransfer({
    required int year,
    required int month,
    required double amount,
    required List<int> slipBytes,
    required String slipFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/deposit-transfers'),
    );
    request.headers.addAll(await _headers(auth: true)..remove('Content-Type'));
    request.fields['year'] = year.toString();
    request.fields['month'] = month.toString();
    request.fields['amount'] = amount.toString();
    request.files.add(http.MultipartFile.fromBytes(
      'slip',
      slipBytes,
      filename: slipFilename,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return DriverDepositTransfer.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<TrackingStatus> startTracking(int hireId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/hires/$hireId/tracking/start'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return TrackingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<TrackingStatus> completeHire(int hireId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/hires/$hireId/tracking/complete'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return TrackingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<TrackingStatus> stopTracking(int hireId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/hires/$hireId/tracking/stop'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return TrackingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<TrackingStatus> sendTrackingPoint(
    int hireId, {
    required double latitude,
    required double longitude,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/driver/hires/$hireId/tracking/points'),
      headers: await _headers(auth: true),
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );

    if (response.statusCode == 200) {
      return TrackingStatus.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<List<HireExpense>> fetchDriverExpenses({String? category}) async {
    final uri = Uri.parse('$baseUrl/driver/expenses').replace(
      queryParameters: category != null ? {'category': category} : null,
    );
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => HireExpense.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<List<HireExpense>> fetchExpenses(int hireId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/hires/$hireId/expenses'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => HireExpense.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<HireExpense> addExpense(
    int hireId, {
    required String category,
    required double amount,
    List<int>? receiptBytes,
    String? receiptFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/hires/$hireId/expenses'),
    );
    request.headers.addAll(await _headers(auth: true)..remove('Content-Type'));
    request.fields['category'] = category;
    request.fields['amount'] = amount.toString();
    if (receiptBytes != null && receiptFilename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'receipt',
        receiptBytes,
        filename: receiptFilename,
      ));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return HireExpense.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Logs an expense (Fuel, Foods, Room, Parking, Highway) without tying it
  /// to a specific hire — reached from the Options page rather than a
  /// hire's quick actions. Still counts toward the month's salary deduction.
  Future<HireExpense> addStandaloneExpense({
    required String category,
    required double amount,
    List<int>? receiptBytes,
    String? receiptFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/expenses'),
    );
    request.headers.addAll(await _headers(auth: true)..remove('Content-Type'));
    request.fields['category'] = category;
    request.fields['amount'] = amount.toString();
    if (receiptBytes != null && receiptFilename != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'receipt',
        receiptBytes,
        filename: receiptFilename,
      ));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return HireExpense.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<List<Vehicle>> fetchVehicles() async {
    final response = await http.get(
      Uri.parse('$baseUrl/driver/vehicles'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<List<VehicleMaintenanceRecord>> fetchVehicleMaintenanceRecords({String? type}) async {
    final uri = Uri.parse('$baseUrl/driver/vehicle-maintenance').replace(
      queryParameters: type != null ? {'type': type} : null,
    );
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>)
          .map((e) => VehicleMaintenanceRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<VehicleMaintenanceRecord> addVehicleMaintenanceRecord({
    required int vehicleId,
    required String type,
    int? mileage,
    required double cost,
    String? description,
    required List<int> billBytes,
    required String billFilename,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/driver/vehicle-maintenance'),
    );
    request.headers.addAll(await _headers(auth: true)..remove('Content-Type'));
    request.fields['vehicle_id'] = vehicleId.toString();
    request.fields['type'] = type;
    if (mileage != null) request.fields['mileage'] = mileage.toString();
    request.fields['cost'] = cost.toString();
    if (description != null && description.isNotEmpty) request.fields['description'] = description;
    request.files.add(http.MultipartFile.fromBytes(
      'bill',
      billBytes,
      filename: billFilename,
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return VehicleMaintenanceRecord.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  String _extractError(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          return firstError.first.toString();
        }
      }

      if (data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {
      // Fall through to the generic message below.
    }

    return 'Something went wrong (HTTP ${response.statusCode}).';
  }
}
