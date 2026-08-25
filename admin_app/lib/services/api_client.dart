import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/admin_user.dart';
import '../models/hire.dart';
import '../models/place_suggestion.dart';
import '../models/reference_data.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._internal();

  static final ApiClient instance = ApiClient._internal();

  /// Base URL of the Car Rental CMS API — same resolution order as the
  /// driver app's client (see its longer comment): a baked-in
  /// --dart-define=API_BASE_URL for exported builds wins first; otherwise
  /// 10.0.2.2 for the Android emulator (its alias for the host machine),
  /// else plain localhost (web / iOS simulator / desktop dev).
  static String get baseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8000/api';
    }
    return 'http://localhost:8000/api';
  }

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
    final response = await http.post(
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
      await http.post(
        Uri.parse('$baseUrl/admin/auth/logout'),
        headers: await _headers(auth: true),
      );
    } finally {
      _cachedToken = null;
      await _storage.delete(key: _tokenKey);
    }
  }

  Future<AdminUser> fetchMe() async {
    final response = await http.get(
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
    final response = await http.get(uri, headers: await _headers(auth: true));

    if (response.statusCode == 200) {
      return HirePage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<Hire> fetchHire(int id) async {
    final response = await http.get(
      Uri.parse('$baseUrl/admin/hires/$id'),
      headers: await _headers(auth: true),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Hire.fromJson(data['data'] as Map<String, dynamic>);
    }

    throw ApiException(_extractError(response));
  }

  Future<ReferenceData> fetchReferenceData() async {
    final response = await http.get(
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
    final response = await http.post(
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
      final response = await http.get(uri, headers: await _headers(auth: true));
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
      final response = await http.get(uri, headers: await _headers(auth: true));
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
