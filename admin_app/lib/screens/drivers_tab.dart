import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/driver.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/state_views.dart';
import 'driver_detail_screen.dart';
import 'driver_form_screen.dart';

/// The Drivers tab: the roster, searchable, with add/view (edit/delete live
/// on the driver's own page). Embedded under HomeScreen's shared AppBar and
/// TabBar — this widget owns only its body and its own FAB.
class DriversTab extends StatefulWidget {
  const DriversTab({super.key, this.user});

  final AdminUser? user;

  @override
  State<DriversTab> createState() => _DriversTabState();
}

class _DriversTabState extends State<DriversTab> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Driver> _drivers = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  int _generation = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _canAdd => widget.user?.canCreateDrivers ?? false;

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
      final page = await ApiClient.instance.fetchDrivers(search: _searchController.text.trim(), page: 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _drivers = page.drivers;
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
      final page = await ApiClient.instance.fetchDrivers(search: _searchController.text.trim(), page: _page + 1);
      if (!mounted || generation != _generation) return;
      setState(() {
        _drivers = [..._drivers, ...page.drivers];
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
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _addDriver() async {
    final added = await Navigator.of(context).push<Driver>(
      MaterialPageRoute(builder: (_) => const DriverFormScreen()),
    );
    if (added == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${added.name} added.')));
    _load(silent: true);
  }

  Future<void> _openDriver(Driver driver) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DriverDetailScreen(driver: driver, user: widget.user)),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              key: const Key('add-driver'),
              onPressed: _addDriver,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Driver'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const Key('driver-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search drivers…',
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
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    if (_drivers.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: EmptyState(
          icon: Icons.badge_outlined,
          title: _searching ? 'No drivers match' : 'No drivers yet',
          message: _searching
              ? 'Try a different search.'
              : (_canAdd ? 'Add your first driver to build the roster.' : 'Drivers will show up here.'),
          action: !_searching && _canAdd
              ? ElevatedButton.icon(
                  onPressed: _addDriver,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Driver'),
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
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: _drivers.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _drivers.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              );
            }
            final driver = _drivers[index];
            return _DriverTile(driver: driver, onTap: () => _openDriver(driver));
          },
        ),
      ),
    );
  }
}

class _DriverTile extends StatelessWidget {
  const _DriverTile({required this.driver, required this.onTap});

  final Driver driver;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: Key('driver-card-${driver.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.badge_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(
                      driver.contactNumber,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
