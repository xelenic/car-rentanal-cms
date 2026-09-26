import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_tile.dart';
import 'add_vehicle_screen.dart';
import 'login_screen.dart';
import 'my_expenses_screen.dart';
import 'vehicle_detail_screen.dart';

/// The app's home: the fleet as a grid of icon-and-name tiles, narrowed by
/// search or by condition. Everything about a vehicle — and its hires — is on
/// its own page, one tap away.
class VehiclesDashboardScreen extends StatefulWidget {
  const VehiclesDashboardScreen({super.key});

  @override
  State<VehiclesDashboardScreen> createState() => _VehiclesDashboardScreenState();
}

class _VehiclesDashboardScreenState extends State<VehiclesDashboardScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  AdminUser? _user;
  List<Vehicle> _vehicles = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// The condition being filtered to, or null for every vehicle.
  String? _condition;

  /// Bumped on every fresh load, so a slow answer to an old search or filter
  /// can't overwrite a newer one.
  int _generation = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _filtering => _searching || _condition != null;
  bool get _canAdd => _user?.canCreateVehicles ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait<Object?>([
        ApiClient.instance.fetchVehicles(search: _searchController.text.trim(), condition: _condition, page: 1),
        // Who is signed in decides what is offered (Add Vehicle, and on the
        // pages after this one Edit/Delete). Not worth failing the whole
        // screen over, so a failed lookup just offers less.
        if (_user == null) ApiClient.instance.fetchMe().then<AdminUser?>((u) => u, onError: (_) => null),
      ]);
      if (!mounted || generation != _generation) return;

      final page = results.first as VehiclePage;
      setState(() {
        if (results.length > 1) _user = results[1] as AdminUser?;
        _vehicles = page.vehicles;
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);

    try {
      final page = await ApiClient.instance.fetchVehicles(
        search: _searchController.text.trim(),
        condition: _condition,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _vehicles = [..._vehicles, ...page.vehicles];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // the clear button follows the text
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _setCondition(String? condition) {
    if (condition == _condition) return;
    setState(() => _condition = condition);
    _load();
  }

  Future<void> _addVehicle() async {
    final added = await Navigator.of(context).push<Vehicle>(
      MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
    );
    if (added == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${added.model} added.')));
    _load(silent: true);
  }

  Future<void> _openVehicle(Vehicle vehicle) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle, user: _user)),
    );
    if (mounted) _load(silent: true);
  }

  void _openMyExpenses() {
    final user = _user;
    if (user == null) return;

    Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyExpensesScreen(user: user)));
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vehicles'),
        actions: [
          if (_user?.canViewMyExpenses ?? false)
            IconButton(
              key: const Key('my-expenses'),
              tooltip: 'My Expenses',
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: _openMyExpenses,
            ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              key: const Key('add-vehicle'),
              onPressed: _addVehicle,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Vehicle'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('vehicle-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search vehicles…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searching
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          _load();
                        },
                      )
                    : null,
              ),
            ),
          ),
          _ConditionFilter(selected: _condition, onSelected: _setCondition),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_vehicles.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: EmptyState(
          icon: Icons.directions_car_outlined,
          title: _filtering ? 'No vehicles match' : 'No vehicles yet',
          message: _filtering
              ? 'Try a different search or filter.'
              : (_canAdd ? 'Add your first vehicle to start tracking its hires.' : 'Vehicles will show up here.'),
          action: !_filtering && _canAdd
              ? ElevatedButton.icon(
                  onPressed: _addVehicle,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Vehicle'),
                )
              : null,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final vehicle = _vehicles[index];
                    return VehicleTile(vehicle: vehicle, onTap: () => _openVehicle(vehicle));
                  },
                  childCount: _vehicles.length,
                ),
              ),
            ),
            if (_hasMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 96),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "All · New · Excellent · Good · Fair · Poor" — one tap narrows the fleet
/// to a condition.
class _ConditionFilter extends StatelessWidget {
  const _ConditionFilter({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    // A plain scrolling row rather than a lazy list: there are only six chips,
    // and each should exist even while scrolled out of view.
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Row(
          children: [
            _chip('All', null),
            for (final condition in vehicleConditions) _chip(condition, condition),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final isSelected = selected == value;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: Key('condition-${value ?? 'all'}'),
        label: Text(label),
        // Snug enough that all six fit across a phone without scrolling.
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        showCheckmark: false,
        selectedColor: AppColors.surfaceElevated,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}
