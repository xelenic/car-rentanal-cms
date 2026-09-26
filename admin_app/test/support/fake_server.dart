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
    this.canUpdateHires = true,
    this.canDeleteHires = true,
    this.canViewMyExpenses = true,
    this.canCreateMyExpenses = true,
    this.canUpdateMyExpenses = true,
    this.canDeleteMyExpenses = true,
    this.pageSize = 20,
    List<Map<String, dynamic>>? expenses,
    List<Map<String, dynamic>>? expenseCategories,
    List<Map<String, dynamic>>? incomes,
    this.profitBeforeExpenses = 6400,
    this.otherIncomeTotal = 0,
    this.otherIncomeCount = 0,
    Map<int, Map<String, dynamic>>? periods,
    Map<String, Map<String, dynamic>>? statsByPeriod,
  })  : vehicles = vehicles ?? [],
        hires = hires ?? {},
        expenses = expenses ?? [],
        expenseCategories = expenseCategories ?? defaultExpenseCategories(),
        incomes = incomes ?? [],
        periods = periods ?? {},
        statsByPeriod = statsByPeriod ?? {};

  final List<Map<String, dynamic>> vehicles;

  /// Hires per vehicle id, each already in the API's JSON shape and already
  /// tagged with a "_tab" the fake serves them under.
  final Map<int, List<Map<String, dynamic>>> hires;

  bool canCreateVehicles;
  bool canCreateHires;
  bool canUpdateHires;
  bool canDeleteHires;
  bool canViewMyExpenses;
  bool canCreateMyExpenses;
  bool canUpdateMyExpenses;
  bool canDeleteMyExpenses;
  int pageSize;

  /// The owner's expenses, in the API's shape, and the categories they are filed under.
  final List<Map<String, dynamic>> expenses;
  final List<Map<String, dynamic>> expenseCategories;

  /// The owner's other income, in the API's shape.
  final List<Map<String, dynamic>> incomes;

  /// The month's profit from hires — whatever month is asked for.
  num profitBeforeExpenses;

  /// Other income (not a hire) for whatever month is asked for; it is added to My Profit.
  num otherIncomeTotal;
  int otherIncomeCount;


  /// Per vehicle id: the {years, months_by_year} the periods endpoint answers with.
  final Map<int, Map<String, dynamic>> periods;

  /// "year-month" (or just "year") -> the stats a vehicle shows when viewed for that period.
  final Map<String, Map<String, dynamic>> statsByPeriod;

  /// Fail only requests of this HTTP method, e.g. {'DELETE': 403}.
  final Map<String, int> failMethods = {};

  final List<http.Request> requests = [];
  final List<Map<String, dynamic>> createdVehicles = [];
  final List<Map<String, dynamic>> createdHires = [];
  final List<({int id, Map<String, dynamic> body})> updatedHires = [];
  final List<int> deletedHires = [];
  final List<({int? id, Map<String, dynamic> body})> savedExpenses = [];
  final List<int> deletedExpenses = [];
  final List<({int? id, Map<String, dynamic> body})> savedIncomes = [];
  final List<int> deletedIncomes = [];
  final List<String> createdCategories = [];
  final List<({int id, String name})> renamedCategories = [];
  final List<int> deletedCategories = [];

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

  static String _tidy(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

  String? _categoryNameProblem(String name, int? ownId) {
    if (name.isEmpty) return 'The name field is required.';
    final taken = expenseCategories.any((c) => c['id'] != ownId && (c['name'] as String).toLowerCase() == name.toLowerCase());
    return taken ? 'A category with this name already exists.' : null;
  }

  Map<String, dynamic> _addCategory(String name) {
    final base = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    var key = base.isEmpty ? 'category' : base;
    for (var n = 2; expenseCategories.any((c) => c['key'] == key); n++) {
      key = '${base.isEmpty ? 'category' : base}-$n';
    }
    final category = {
      'id': (expenseCategories.map((c) => c['id'] as int).fold<int>(0, (a, b) => a > b ? a : b)) + 1,
      'key': key,
      'name': name,
    };
    expenseCategories.add(category);
    expenseCategories.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
    return category;
  }

  Map<String, dynamic> _categoryJson(Map<String, dynamic> category) => {
        ...category,
        'expenses_count': expenses.where((e) => e['category'] == category['key']).length,
      };

  String _categoryName(String key) =>
      expenseCategories.where((c) => c['key'] == key).map((c) => c['name'] as String).firstOrNull ?? key;

  ({int year, int month, int page, String search}) _period(http.Request request) {
    final q = request.url.queryParameters;
    final now = DateTime.now();
    return (
      year: int.parse(q['year'] ?? '${now.year}'),
      month: int.parse(q['month'] ?? '${now.month}'),
      page: int.parse(q['page'] ?? '1'),
      search: (q['search'] ?? '').toLowerCase(),
    );
  }

  static bool _inMonth(Map<String, dynamic> row, String dateKey, int year, int month) =>
      (row[dateKey] as String).startsWith('$year-${month.toString().padLeft(2, '0')}');

  /// The cards' figures for one month, worked out from what is in the fake's lists
  /// (plus whatever fixed [otherIncomeTotal] / [otherIncomeCount] a test set).
  Map<String, dynamic> _summary(int year, int month) {
    final inMonth = expenses.where((e) => _inMonth(e, 'expense_date', year, month)).toList();
    final total = inMonth.fold<double>(0, (sum, e) => sum + (e['amount'] as num));
    final incomeInMonth = incomes.where((i) => _inMonth(i, 'income_date', year, month)).toList();
    final income = otherIncomeTotal + incomeInMonth.fold<double>(0, (sum, i) => sum + (i['amount'] as num));

    final byCategory = <String, double>{};
    for (final e in inMonth) {
      byCategory[e['category'] as String] = (byCategory[e['category']] ?? 0) + (e['amount'] as num);
    }
    final sorted = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return {
      'year': year,
      'month': month,
      'label': '${_monthNames[month - 1]} $year',
      'total': total,
      'record_count': inMonth.length,
      'profit_before_expenses': profitBeforeExpenses,
      'other_income_total': income,
      'other_income_count': otherIncomeCount + incomeInMonth.length,
      'my_profit': profitBeforeExpenses + income - total,
      'by_category': [for (final e in sorted) {'key': e.key, 'name': _categoryName(e.key), 'total': e.value}],
      'breakdown': {
        'our_hire_value_total': 8000,
        'expenses_total': 0,
        'net_before_salary': 8000,
        'salary_percentage': 20,
        'salary_total': 1600,
        'leasing_installment_total': 0,
        'repair_cost_total': 0,
        'profit_total': profitBeforeExpenses,
      },
    };
  }

  List<int> _years(int year) {
    int yearOf(Map<String, dynamic> row, String key) => int.parse((row[key] as String).substring(0, 4));
    return {
      DateTime.now().year,
      year,
      ...expenses.map((e) => yearOf(e, 'expense_date')),
      ...incomes.map((i) => yearOf(i, 'income_date')),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
  }

  http.Response _expensesList(http.Request request) {
    final q = request.url.queryParameters;
    final p = _period(request);

    final matching = expenses
        .where((e) => _inMonth(e, 'expense_date', p.year, p.month))
        .where((e) => q['category'] == null || e['category'] == q['category'])
        .where((e) => p.search.isEmpty || '${e['title']} ${e['notes'] ?? ''}'.toLowerCase().contains(p.search))
        .toList()
      ..sort((a, b) => (b['expense_date'] as String).compareTo(a['expense_date'] as String));

    final start = (p.page - 1) * pageSize;
    return _json({
      'data': matching.skip(start).take(pageSize).toList(),
      'meta': {'current_page': p.page, 'last_page': (matching.length / pageSize).ceil().clamp(1, 999)},
      'summary': _summary(p.year, p.month),
      'filtered_total': matching.fold<double>(0, (sum, e) => sum + (e['amount'] as num)),
      'years': _years(p.year),
    });
  }

  http.Response _incomesList(http.Request request) {
    final p = _period(request);

    final matching = incomes
        .where((i) => _inMonth(i, 'income_date', p.year, p.month))
        .where((i) => p.search.isEmpty || '${i['title']} ${i['notes'] ?? ''}'.toLowerCase().contains(p.search))
        .toList()
      ..sort((a, b) => (b['income_date'] as String).compareTo(a['income_date'] as String));

    final start = (p.page - 1) * pageSize;
    return _json({
      'data': matching.skip(start).take(pageSize).toList(),
      'meta': {'current_page': p.page, 'last_page': (matching.length / pageSize).ceil().clamp(1, 999)},
      'summary': _summary(p.year, p.month),
      'filtered_total': matching.fold<double>(0, (sum, i) => sum + (i['amount'] as num)),
      'years': _years(p.year),
    });
  }

  http.Response _incomeSave(http.Request request, int? id) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    savedIncomes.add((id: id, body: body));

    http.Response invalid(String field, String message) =>
        _json({'message': message, 'errors': {field: [message]}}, 422);

    if (((body['title'] ?? '') as String).trim().isEmpty) return invalid('title', 'The title field is required.');
    final amount = num.tryParse('${body['amount']}');
    if (amount == null || amount <= 0) return invalid('amount', 'The amount field must be at least 0.01.');

    final saved = {
      'id': id ?? (incomes.map((i) => i['id'] as int).fold<int>(0, (a, b) => a > b ? a : b)) + 1,
      'title': (body['title'] as String).trim(),
      'amount': amount,
      'income_date': body['income_date'],
      'notes': body['notes'],
    };

    if (id == null) {
      incomes.add(saved);
    } else {
      final index = incomes.indexWhere((i) => i['id'] == id);
      if (index < 0) return _json({'message': 'Not found.'}, 404);
      incomes[index] = saved;
    }

    return _json({'data': saved}, id == null ? 201 : 200);
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  http.Response _expenseSave(http.Request request, int? id) {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    savedExpenses.add((id: id, body: body));

    Map<String, dynamic> errors(String field, String message) => {
          'message': message,
          'errors': {field: [message]},
        };

    if (((body['title'] ?? '') as String).trim().isEmpty) return _json(errors('title', 'The title field is required.'), 422);
    final amount = num.tryParse('${body['amount']}');
    if (amount == null || amount <= 0) return _json(errors('amount', 'The amount field must be at least 0.01.'), 422);

    var category = body['category'] as String;
    if (category == '__new__') {
      final name = _tidy((body['new_category'] ?? '') as String);
      if (name.isEmpty) return _json(errors('new_category', 'Type a name for the new category.'), 422);
      final existing = expenseCategories.where((c) => (c['name'] as String).toLowerCase() == name.toLowerCase()).firstOrNull;
      category = (existing ?? _addCategory(name))['key'] as String;
    } else if (!expenseCategories.any((c) => c['key'] == category)) {
      return _json(errors('category', 'The selected category is invalid.'), 422);
    }

    final saved = {
      'id': id ?? (expenses.map((e) => e['id'] as int).fold<int>(0, (a, b) => a > b ? a : b)) + 1,
      'title': (body['title'] as String).trim(),
      'category': category,
      'category_name': _categoryName(category),
      'amount': amount,
      'expense_date': body['expense_date'],
      'notes': body['notes'],
    };

    if (id == null) {
      expenses.add(saved);
    } else {
      final index = expenses.indexWhere((e) => e['id'] == id);
      if (index < 0) return _json({'message': 'Not found.'}, 404);
      expenses[index] = saved;
    }

    return _json({'data': saved}, id == null ? 201 : 200);
  }

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path.replaceFirst(RegExp(r'^/api'), '');

    if (failWith != null) return _json({'message': 'The server said no.'}, failWith!);
    if (failMethods[request.method] != null) {
      return _json({'message': 'The server said no.'}, failMethods[request.method]!);
    }

    if (path == '/admin/me') {
      return _json({
        'id': 1,
        'name': 'ZZZ Test Admin',
        'email': 'zzz@example.test',
        'can_create_hires': canCreateHires,
        'can_update_hires': canUpdateHires,
        'can_delete_hires': canDeleteHires,
        'can_view_my_expenses': canViewMyExpenses,
        'can_create_my_expenses': canCreateMyExpenses,
        'can_update_my_expenses': canUpdateMyExpenses,
        'can_delete_my_expenses': canDeleteMyExpenses,
        'can_view_vehicles': true,
        'can_create_vehicles': canCreateVehicles,
      });
    }

    if (path == '/admin/my-expenses' && request.method == 'GET') return _expensesList(request);
    if (path == '/admin/my-expenses' && request.method == 'POST') return _expenseSave(request, null);
    final expenseOne = RegExp(r'^/admin/my-expenses/(\d+)$').firstMatch(path);
    if (expenseOne != null && request.method == 'PUT') return _expenseSave(request, int.parse(expenseOne.group(1)!));
    if (expenseOne != null && request.method == 'DELETE') {
      final id = int.parse(expenseOne.group(1)!);
      final found = expenses.where((e) => e['id'] == id).firstOrNull;
      if (found == null) return _json({'message': 'Not found.'}, 404);
      expenses.remove(found);
      deletedExpenses.add(id);
      return _json({'message': 'Expense "${found['title']}" was deleted.'});
    }

    if (path == '/admin/other-incomes' && request.method == 'GET') return _incomesList(request);
    if (path == '/admin/other-incomes' && request.method == 'POST') return _incomeSave(request, null);
    final incomeOne = RegExp(r'^/admin/other-incomes/(\d+)$').firstMatch(path);
    if (incomeOne != null && request.method == 'PUT') return _incomeSave(request, int.parse(incomeOne.group(1)!));
    if (incomeOne != null && request.method == 'DELETE') {
      final id = int.parse(incomeOne.group(1)!);
      final found = incomes.where((i) => i['id'] == id).firstOrNull;
      if (found == null) return _json({'message': 'Not found.'}, 404);
      incomes.remove(found);
      deletedIncomes.add(id);
      return _json({'message': 'Income "${found['title']}" was deleted.'});
    }

    if (path == '/admin/my-expense-categories' && request.method == 'GET') {
      return _json({'data': expenseCategories.map(_categoryJson).toList()});
    }
    if (path == '/admin/my-expense-categories' && request.method == 'POST') {
      final name = _tidy(((jsonDecode(request.body) as Map<String, dynamic>)['name'] ?? '') as String);
      final problem = _categoryNameProblem(name, null);
      if (problem != null) return _json({'message': problem, 'errors': {'name': [problem]}}, 422);
      final created = _addCategory(name);
      createdCategories.add(name);
      return _json({'data': _categoryJson(created)}, 201);
    }
    final categoryOne = RegExp(r'^/admin/my-expense-categories/(\d+)$').firstMatch(path);
    if (categoryOne != null) {
      final id = int.parse(categoryOne.group(1)!);
      final category = expenseCategories.where((c) => c['id'] == id).firstOrNull;
      if (category == null) return _json({'message': 'Not found.'}, 404);

      if (request.method == 'PUT') {
        final name = _tidy(((jsonDecode(request.body) as Map<String, dynamic>)['name'] ?? '') as String);
        final problem = _categoryNameProblem(name, id);
        if (problem != null) return _json({'message': problem, 'errors': {'name': [problem]}}, 422);
        category['name'] = name;
        renamedCategories.add((id: id, name: name));
        return _json({'data': _categoryJson(category)});
      }

      if (request.method == 'DELETE') {
        final inUse = expenses.where((e) => e['category'] == category['key']).length;
        if (inUse > 0) {
          return _json({'message': '"${category['name']}" is used by $inUse ${inUse == 1 ? 'expense' : 'expenses'} — move or delete them first.'}, 422);
        }
        expenseCategories.remove(category);
        deletedCategories.add(id);
        return _json({'message': 'Category "${category['name']}" was deleted.'});
      }
    }

    if (path == '/admin/vehicles' && request.method == 'GET') {
      final search = (request.url.queryParameters['search'] ?? '').toLowerCase();
      final condition = request.url.queryParameters['condition'];
      final page = int.parse(request.url.queryParameters['page'] ?? '1');
      final matching = vehicles
          .where((v) => search.isEmpty || '${v['model']} ${v['condition']}'.toLowerCase().contains(search))
          .where((v) => condition == null || v['condition'] == condition)
          .toList();
      final start = (page - 1) * pageSize;
      final slice = matching.skip(start).take(pageSize).toList();
      return _json({
        'data': slice,
        'meta': {'current_page': page, 'last_page': (matching.length / pageSize).ceil().clamp(1, 999)},
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
      final year = request.url.queryParameters['year'];
      final month = request.url.queryParameters['month'];
      bool inPeriod(Map<String, dynamic> h) {
        if (year == null) return true;
        final tag = h['_month'] as String?; // "2026-09", from the hire's start time
        if (tag == null) return false;
        return month == null ? tag.startsWith('$year-') : tag == '$year-${month.padLeft(2, '0')}';
      }

      final all = (hires[id] ?? []).where((h) => tab == 'all' || h['_tab'] == tab).where(inPeriod).toList();
      final start = (page - 1) * pageSize;
      return _json({
        'data': all.skip(start).take(pageSize).map((h) => {...h}..remove('_tab')..remove('_month')).toList(),
        'meta': {'current_page': page, 'last_page': (all.length / pageSize).ceil().clamp(1, 999)},
      });
    }

    final vehiclePeriods = RegExp(r'^/admin/vehicles/(\d+)/periods$').firstMatch(path);
    if (vehiclePeriods != null) {
      final id = int.parse(vehiclePeriods.group(1)!);
      return _json(periods[id] ?? {'years': [], 'months_by_year': {}});
    }

    final vehicleOne = RegExp(r'^/admin/vehicles/(\d+)$').firstMatch(path);
    if (vehicleOne != null) {
      final id = int.parse(vehicleOne.group(1)!);
      final vehicle = vehicles.where((v) => v['id'] == id).firstOrNull;
      if (vehicle == null) return _json({'message': 'Not found.'}, 404);
      final year = request.url.queryParameters['year'];
      final month = request.url.queryParameters['month'];
      final key = year == null ? null : (month == null ? year : '$year-$month');
      if (key != null && statsByPeriod[key] != null) {
        return _json({'data': {...vehicle, 'stats': statsByPeriod[key]}});
      }
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
      return _json({'data': {...hire}..remove('_tab')..remove('_month')}, 201);
    }

    final hireWrite = RegExp(r'^/admin/hires/(\d+)$').firstMatch(path);
    if (hireWrite != null && request.method == 'PUT') {
      final id = int.parse(hireWrite.group(1)!);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      updatedHires.add((id: id, body: body));
      for (final list in hires.values) {
        final found = list.where((h) => h['id'] == id).firstOrNull;
        if (found == null) continue;
        found
          ..['description'] = body['description']
          ..['hire_full_value'] = num.parse('${body['hire_full_value']}')
          ..['our_hire_value'] = num.parse('${body['our_hire_value']}')
          ..['from_location'] = body['from_location_name'] ?? found['from_location']
          ..['to_location'] = body['to_location_name'] ?? found['to_location']
          ..['start_time'] = body['start_time'];
        return _json({'data': {...found}..remove('_tab')..remove('_month')});
      }
      return _json({'message': 'Not found.'}, 404);
    }

    if (hireWrite != null && request.method == 'DELETE') {
      final id = int.parse(hireWrite.group(1)!);
      deletedHires.add(id);
      for (final entry in hires.entries) {
        final found = entry.value.where((h) => h['id'] == id).firstOrNull;
        if (found == null) continue;
        entry.value.remove(found);
        final vehicle = vehicles.where((v) => v['id'] == entry.key).firstOrNull;
        if (vehicle != null) {
          final counts = (vehicle['stats'] as Map<String, dynamic>)['counts'] as Map<String, dynamic>;
          counts['all'] = (counts['all'] as int) - 1;
          counts[found['_tab']] = (counts[found['_tab']] as int) - 1;
        }
        return _json({'message': 'Hire #$id was deleted.'});
      }
      return _json({'message': 'Not found.'}, 404);
    }

    final hireOne = RegExp(r'^/admin/hires/(\d+)$').firstMatch(path);
    if (hireOne != null) {
      final id = int.parse(hireOne.group(1)!);
      for (final list in hires.values) {
        final found = list.where((h) => h['id'] == id).firstOrNull;
        if (found != null) return _json({'data': {...found}..remove('_tab')..remove('_month')});
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

/// A hire in the API's shape. [tab] is the fake's own routing tag, and so is
/// the month tag it derives from [startTime].
Map<String, dynamic> hireJson({
  required int id,
  int? vehicleId,
  String tab = 'today',
  String customer = 'ZZZ Test Customer',
  int customerId = 1,
  String status = 'pending',
  String tourType = 'drop_pickup',
  String? startTime,
  String? endTime,
  String? from = 'ZZZ From',
  String? to = 'ZZZ To',
  List<String> stayLocations = const [],
  List<List<String>> dayLocations = const [],
  int? packageId,
  int? driverId,
  String? driver,
  String? description,
  String? cancelReason,
  num full = 1000,
  num? our,
}) =>
    {
      '_tab': tab,
      '_month': startTime?.substring(0, 7),
      'id': id,
      'tour_type': tourType,
      'tour_type_label': switch (tourType) {
        'day_tour' => 'Day Tour',
        'multi_day' => 'Multi Day Tour',
        'package' => 'Package',
        _ => 'Drop and Pickup',
      },
      'status': status,
      'status_label': switch (status) {
        'started' => 'Driver Hire Started',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        _ => 'Pending',
      },
      'is_upcoming': false,
      'start_time': startTime,
      'end_time': endTime,
      'from_location': from,
      'to_location': to,
      'stay_locations': stayLocations,
      'day_locations': dayLocations,
      'package_id': packageId,
      'package': packageId == null ? null : 'ZZZ Test Package',
      'hire_full_value': full,
      'our_hire_value': our ?? full * 0.8,
      'commission': full - (our ?? full * 0.8),
      'payment_type': 'cash',
      'payment_type_label': 'Cash',
      'paid_amount': 0,
      'balance_remaining': full,
      'payment_status': 'unpaid',
      'customer': {'id': customerId, 'name': customer, 'phone': '0770000000'},
      'driver': driver == null ? null : {'id': driverId ?? 1, 'name': driver},
      'vehicle': vehicleId == null ? null : {'id': vehicleId, 'model': 'ZZZ Test Van'},
      'description': description,
      'is_tracking': false,
      'total_distance_km': 0,
      'cancelled_at': null,
      'cancel_reason': cancelReason,
      'created_at': null,
    };


/// The nine categories My Expenses starts with, A to Z.
List<Map<String, dynamic>> defaultExpenseCategories() {
  const names = {
    'fuel': 'Fuel',
    'insurance': 'Insurance',
    'marketing': 'Marketing',
    'office': 'Office & Supplies',
    'others': 'Others',
    'personal': 'Personal',
    'rent': 'Rent',
    'taxes': 'Taxes & Licences',
    'utilities': 'Utilities',
  };
  var id = 0;
  return [for (final e in names.entries) {'id': ++id, 'key': e.key, 'name': e.value}];
}

/// An expense in the API's shape.
Map<String, dynamic> expenseJson({
  required int id,
  String title = 'ZZZ Test Rent',
  String category = 'rent',
  String categoryName = 'Rent',
  num amount = 1000,
  required String date,
  String? notes,
}) =>
    {
      'id': id,
      'title': title,
      'category': category,
      'category_name': categoryName,
      'amount': amount,
      'expense_date': date,
      'notes': notes,
    };

/// A day of the given month, as the API writes dates: "2026-09-05".
String dayOf(DateTime month, int day) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

/// A piece of other income in the API's shape.
Map<String, dynamic> incomeJson({
  required int id,
  String title = 'ZZZ Shop rent',
  num amount = 1000,
  required String date,
  String? notes,
}) =>
    {'id': id, 'title': title, 'amount': amount, 'income_date': date, 'notes': notes};
