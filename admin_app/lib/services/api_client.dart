import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/admin_user.dart';
import '../models/hire.dart';
import '../models/hire_period.dart';
import '../models/hire_tab.dart';
import '../models/my_expense.dart';
import '../models/place_suggestion.dart';
import '../models/reference_data.dart';
import '../models/vehicle.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  static const _productionBaseUrl = 'https://xnatureland1.xelenic.com/api';

  /// Base URL of the Car Rental CMS API — same resolution order as the
  /// driver app's client: a --dart-define=API_BASE_URL always wins; every
  /// release build of the mobile app (the exported APK) otherwise defaults
  /// to the production server, so it never depends on a build flag (web is
  /// excluded — the locally served web preview must keep hitting the local
  /// dev server); debug builds use 10.0.2.2 for the Android emulator (its
  /// alias for the host machine), else plain localhost.
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (kReleaseMode && !kIsWeb) return _productionBaseUrl;

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

  http.Client _http = http.Client();

  /// Lets a test answer requests itself (package:http's MockClient).
  @visibleForTesting
  void useHttpClient(http.Client client) => _http = client;

  final _storage = const FlutterSecureStorage();
  static const _tokenKey = 'admin_app_token';

  String? _cachedToken;

  Future<String?> get _token async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: _tokenKey);
    } catch (_) {
      // Secure storage can be unavailable (e.g. no platform channel in a
      // widget test) — treat that the same as "no token stored" rather
      // than crashing the caller.
      _cachedToken = null;
    }
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

  Future<AdminUser> login(String email, String password) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/admin/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['token'] as String;
      _cachedToken = token;
      await _storage.write(key: _tokenKey, value: token);
      return AdminUser.fromJson(data['user'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<void> logout() async {
    try {
      await _http.post(
        Uri.parse('$baseUrl/admin/auth/logout'),
        headers: await _headers(auth: true),
      );
    } finally {
      _cachedToken = null;
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<AdminUser> fetchMe() async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/me'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return AdminUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<HirePage> fetchHires({String? search, bool upcoming = false, int page = 1}) async {
    final uri = Uri.parse('$baseUrl/admin/hires').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (upcoming) 'upcoming': '1',
        'page': '$page',
      },
    );
    final response = await _http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return HirePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<Hire> fetchHire(int id) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/hires/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Hire.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// The fleet, a page at a time, each vehicle with its hire numbers.
  Future<VehiclePage> fetchVehicles({String? search, String? condition, int page = 1}) async {
    final uri = Uri.parse('$baseUrl/admin/vehicles').replace(
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (condition != null && condition.isNotEmpty) 'condition': condition,
        'page': '$page',
      },
    );
    final response = await _http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return VehiclePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// One vehicle with its numbers — for all time, or just [period].
  Future<Vehicle> fetchVehicle(int id, {HirePeriod? period}) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/vehicles/$id').replace(queryParameters: period?.query),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Vehicle.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<Vehicle> createVehicle({
    required String model,
    required String condition,
    required int seats,
    required int pax,
    String? description,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/admin/vehicles'),
      headers: await _headers(auth: true),
      body: jsonEncode({
        'model': model,
        'condition': condition,
        'seats': seats,
        'pax': pax,
        'description': (description ?? '').trim().isEmpty ? null : description!.trim(),
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Vehicle.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// One vehicle's hires under one tab, a page at a time.
  Future<HirePage> fetchVehicleHires(
    int vehicleId, {
    HireTab tab = HireTab.all,
    int page = 1,
    HirePeriod? period,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/vehicles/$vehicleId/hires').replace(
      queryParameters: {'tab': tab.apiValue, 'page': '$page', ...?period?.query},
    );
    final response = await _http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return HirePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// The years and months this vehicle has hires in.
  Future<PeriodOptions> fetchVehiclePeriods(int vehicleId) async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/vehicles/$vehicleId/periods'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return PeriodOptions.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<ReferenceData> fetchReferenceData() async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/hires/reference-data'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      return ReferenceData.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Creates a hire. $data is handed straight through to the API as JSON —
  /// its shape matches HireService::rules(), built by the Create Hire
  /// screen per tour type (see build_hire_payload in that screen).
  Future<Hire> createHire(Map<String, dynamic> data) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/admin/hires'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Hire.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Saves an edited hire. [data] has the same shape as for [createHire].
  Future<Hire> updateHire(int id, Map<String, dynamic> data) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/admin/hires/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return Hire.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Deletes a hire for good, with its payments, expenses and tracking history.
  Future<void> deleteHire(int id) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/admin/hires/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw ApiException(_extractError(response));
  }

  /// One month's expenses (this month when [year]/[month] are omitted), a page
  /// at a time, with the cards' figures for the whole month.
  Future<MyExpensePage> fetchMyExpenses({
    int? year,
    int? month,
    String? category,
    String? search,
    int page = 1,
  }) async {
    final uri = Uri.parse('$baseUrl/admin/my-expenses').replace(
      queryParameters: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
        if (category != null && category.isNotEmpty) 'category': category,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': '$page',
      },
    );
    final response = await _http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return MyExpensePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Adds an expense, or — given [id] — saves changes to one. To file it under
  /// a brand new category pass [newExpenseCategoryOption] as [category] and
  /// the name as [newCategory].
  Future<MyExpense> saveMyExpense({
    int? id,
    required String title,
    required String category,
    String? newCategory,
    required String amount,
    required DateTime date,
    String? notes,
  }) async {
    final body = jsonEncode({
      'title': title,
      'category': category,
      if (category == newExpenseCategoryOption) 'new_category': newCategory,
      'amount': amount,
      'expense_date': formatCalendarDate(date),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    });
    final headers = await _headers(auth: true);
    final response = id == null
        ? await _http.post(Uri.parse('$baseUrl/admin/my-expenses'), headers: headers, body: body)
        : await _http.put(Uri.parse('$baseUrl/admin/my-expenses/$id'), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return MyExpense.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<void> deleteMyExpense(int id) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/admin/my-expenses/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw ApiException(_extractError(response));
  }

  /// One month's other income (this month when [year]/[month] are omitted), a
  /// page at a time, with the cards' figures for the whole month.
  Future<OtherIncomePage> fetchOtherIncomes({int? year, int? month, String? search, int page = 1}) async {
    final uri = Uri.parse('$baseUrl/admin/other-incomes').replace(
      queryParameters: {
        if (year != null) 'year': '$year',
        if (month != null) 'month': '$month',
        if (search != null && search.isNotEmpty) 'search': search,
        'page': '$page',
      },
    );
    final response = await _http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return OtherIncomePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Adds a piece of other income, or — given [id] — saves changes to one.
  Future<OtherIncome> saveOtherIncome({
    int? id,
    required String title,
    required String amount,
    required DateTime date,
    String? notes,
  }) async {
    final body = jsonEncode({
      'title': title,
      'amount': amount,
      'income_date': formatCalendarDate(date),
      'notes': (notes ?? '').trim().isEmpty ? null : notes!.trim(),
    });
    final headers = await _headers(auth: true);
    final response = id == null
        ? await _http.post(Uri.parse('$baseUrl/admin/other-incomes'), headers: headers, body: body)
        : await _http.put(Uri.parse('$baseUrl/admin/other-incomes/$id'), headers: headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return OtherIncome.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<void> deleteOtherIncome(int id) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/admin/other-incomes/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw ApiException(_extractError(response));
  }

  /// Every expense category A to Z, each with how many expenses are filed under it.
  Future<List<ExpenseCategory>> fetchExpenseCategories() async {
    final response = await _http.get(
      Uri.parse('$baseUrl/admin/my-expense-categories'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['data'] as List<dynamic>? ?? []).map((e) => ExpenseCategory.fromJson(e as Map<String, dynamic>)).toList();
    }

    throw ApiException(_extractError(response));
  }

  Future<ExpenseCategory> createExpenseCategory(String name) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/admin/my-expense-categories'),
      headers: await _headers(auth: true),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ExpenseCategory.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<ExpenseCategory> renameExpenseCategory(int id, String name) async {
    final response = await _http.put(
      Uri.parse('$baseUrl/admin/my-expense-categories/$id'),
      headers: await _headers(auth: true),
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return ExpenseCategory.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  /// Deletes a category nothing is filed under; the server refuses (with how many) otherwise.
  Future<void> deleteExpenseCategory(int id) async {
    final response = await _http.delete(
      Uri.parse('$baseUrl/admin/my-expense-categories/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200 || response.statusCode == 204) return;

    throw ApiException(_extractError(response));
  }

  /// Google Places suggestions for a location field's current text —
  /// proxied through the Laravel backend (Api\Admin\PlaceController) so
  /// the Google Maps key never ships inside the app binary. Degrades to
  /// an empty list (never throws) so a location field just falls back to
  /// plain free text if the API/network is unavailable, matching the web
  /// admin panel's Autocomplete widget's own graceful no-op behavior.
  Future<List<PlaceSuggestion>> autocompletePlaces(String input) async {
    final uri = Uri.parse('$baseUrl/admin/places/autocomplete')
        .replace(queryParameters: {'input': input});

    try {
      final response = await _http.get(uri, headers: await _headers(auth: true));
      if (response.statusCode != 200) return const [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return (data['predictions'] as List<dynamic>? ?? [])
          .map((e) => PlaceSuggestion.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// The coordinates for a suggestion the user actually picked — only
  /// called on selection, not on every keystroke.
  Future<PlaceDetails> fetchPlaceDetails(String placeId) async {
    final uri = Uri.parse('$baseUrl/admin/places/details')
        .replace(queryParameters: {'place_id': placeId});

    try {
      final response = await _http.get(uri, headers: await _headers(auth: true));
      if (response.statusCode != 200) return const PlaceDetails();

      return PlaceDetails.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return const PlaceDetails();
    }
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
