import 'dart:async';

import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/hire.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/hire_card.dart';
import '../widgets/state_views.dart';
import 'hire_detail_screen.dart';
import 'hire_form_screen.dart';

/// Every hire across the whole fleet, one tap away from the home screen —
/// unlike before, where a hire was only reachable by drilling into the
/// specific vehicle it belonged to. Same search + "Upcoming only" + paginated
/// list pattern as VehiclesDashboardScreen; booking a hire here opens
/// HireFormScreen with no vehicle pre-selected (its vehicle picker handles
/// that already).
class HiresScreen extends StatefulWidget {
  const HiresScreen({super.key, this.user});

  final AdminUser? user;

  @override
  State<HiresScreen> createState() => _HiresScreenState();
}

class _HiresScreenState extends State<HiresScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Hire> _hires = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _upcomingOnly = false;

  /// Bumped on every fresh load, so a slow answer to an old search or filter
  /// can't overwrite a newer one.
  int _generation = 0;

  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _filtering => _searching || _upcomingOnly;
  bool get _canCreate => widget.user?.canCreateHires ?? false;

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
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        page: 1,
      );
      if (!mounted || generation != _generation) return;

      setState(() {
        _hires = page.hires;
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
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _hires = [..._hires, ...page.hires];
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

  void _toggleUpcoming() {
    setState(() => _upcomingOnly = !_upcomingOnly);
    _load();
  }

  Future<void> _bookHire() async {
    final created = await Navigator.of(context).push<Hire>(
      MaterialPageRoute(builder: (_) => const HireFormScreen()),
    );
    if (created == null || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hire #${created.id} booked.')));
    _load(silent: true);
  }

  Future<void> _open(Hire hire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id, user: widget.user)),
    );
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hires')),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              key: const Key('new-hire'),
              onPressed: _bookHire,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Hire'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('hire-search'),
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by customer or description…',
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
                const SizedBox(width: 10),
                FilterChip(
                  key: const Key('upcoming-only'),
                  label: const Text('Upcoming'),
                  selected: _upcomingOnly,
                  onSelected: (_) => _toggleUpcoming(),
                  showCheckmark: false,
                  selectedColor: AppColors.surfaceElevated,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: _upcomingOnly ? AppColors.primary : AppColors.border),
                  labelStyle: TextStyle(
                    color: _upcomingOnly ? AppColors.primary : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
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

    if (_hires.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: EmptyState(
          icon: Icons.event_note_outlined,
          title: _filtering ? 'No hires match' : 'No hires yet',
          message: _filtering
              ? 'Try a different search or filter.'
              : (_canCreate ? 'Book the first hire to see it here.' : 'Hires will show up here.'),
          action: !_filtering && _canCreate
              ? ElevatedButton.icon(
                  onPressed: _bookHire,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Hire'),
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
          itemCount: _hires.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            if (index >= _hires.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
              );
            }
            final hire = _hires[index];
            return HireCard(hire: hire, onTap: () => _open(hire));
          },
        ),
      ),
    );
  }
}
