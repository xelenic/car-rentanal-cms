import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/state_views.dart';
import '../widgets/vehicle_card.dart';
import 'add_vehicle_screen.dart';
import 'login_screen.dart';
import 'vehicle_detail_screen.dart';

/// The app's home: the fleet as cards — each with its hire numbers — and a
/// header of whole-fleet totals. Hires themselves live on a vehicle's page.
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
  FleetSummary _summary = const FleetSummary();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// Bumped on every fresh load, so a slow answer to an old search can't
  /// overwrite a newer one.
  int _generation = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
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
        ApiClient.instance.fetchVehicles(search: _searchController.text.trim(), page: 1),
        // Who is signed in decides whether "Add vehicle" shows. Not worth
        // failing the whole screen over, so a failed lookup just hides it.
        if (_user == null) ApiClient.instance.fetchMe().then<AdminUser?>((u) => u, onError: (_) => null),
      ]);
      if (!mounted || generation != _generation) return;

      final page = results.first as VehiclePage;
      setState(() {
        if (results.length > 1) _user = results[1] as AdminUser?;
        _vehicles = page.vehicles;
        _summary = page.summary;
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
      MaterialPageRoute(
        builder: (_) => VehicleDetailScreen(
          vehicle: vehicle,
          canCreateHires: _user?.canCreateHires ?? false,
        ),
      ),
    );
    // Hires may have been created there — the cards' numbers with them.
    if (mounted) _load(silent: true);
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              key: const Key('vehicle-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search by model or condition…',
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
          title: _searching ? 'No vehicles match' : 'No vehicles yet',
          message: _searching
              ? 'Try a different search.'
              : (_canAdd ? 'Add your first vehicle to start tracking its hires.' : 'Vehicles will show up here.'),
          action: !_searching && _canAdd
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            if (!_searching) ...[
              _FleetSummaryCard(summary: _summary),
              const SizedBox(height: 16),
            ],
            for (final vehicle in _vehicles) ...[
              VehicleCard(vehicle: vehicle, onTap: () => _openVehicle(vehicle)),
              const SizedBox(height: 10),
            ],
            if (_hasMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              ),
          ],
        ),
      ),
    );
  }
}

/// Whole-fleet totals — the first thing on the dashboard.
class _FleetSummaryCard extends StatelessWidget {
  const _FleetSummaryCard({required this.summary});

  final FleetSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('fleet-summary'),
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            _tile('Vehicles', '${summary.vehicleCount}'),
            _tile('Hires', '${summary.hireCount}'),
            _tile('Hire value', formatRsShort(summary.hireFullValueTotal)),
            _tile('Commission', formatRsShort(summary.commissionTotal)),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75))),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
