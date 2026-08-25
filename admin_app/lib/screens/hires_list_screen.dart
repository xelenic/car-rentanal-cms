import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'create_hire_screen.dart';
import 'hire_detail_screen.dart';
import 'login_screen.dart';

class HiresListScreen extends StatefulWidget {
  const HiresListScreen({super.key});

  @override
  State<HiresListScreen> createState() => _HiresListScreenState();
}

class _HiresListScreenState extends State<HiresListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<Hire> _hires = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  bool _upcomingOnly = false;
  int _page = 1;
  bool _hasMore = false;
  final bool _canCreate = true;

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
    setState(() {
      if (!silent) _loading = true;
      _error = null;
      _page = 1;
    });

    try {
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _hires = page.hires;
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);

    try {
      final page = await ApiClient.instance.fetchHires(
        search: _searchController.text.trim(),
        upcoming: _upcomingOnly,
        page: _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _hires = [..._hires, ...page.hires];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — the user can retry by scrolling again.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
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
        title: const Text('Hires'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      ),
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const CreateHireScreen()),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Hire'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by customer name or phone…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              _load();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Upcoming only'),
                      selected: _upcomingOnly,
                      onSelected: (value) {
                        setState(() => _upcomingOnly = value);
                        _load();
                      },
                      selectedColor: AppColors.surfaceElevated,
                      labelStyle: TextStyle(
                        color: _upcomingOnly ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                      side: BorderSide(
                        color: _upcomingOnly ? AppColors.primary : AppColors.border,
                      ),
                      backgroundColor: AppColors.surface,
                    ),
                  ],
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
      return _ErrorState(message: _error!, onRetry: _load);
    }

    if (_hires.isEmpty) {
      return const _EmptyState();
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
            return _HireCard(
              hire: hire,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id)),
                );
                _load(silent: true);
              },
            );
          },
        ),
      ),
    );
  }
}

class _HireCard extends StatelessWidget {
  const _HireCard({required this.hire, required this.onTap});

  final Hire hire;
  final VoidCallback onTap;

  static final _currency = NumberFormat.currency(locale: 'en_LK', symbol: 'Rs. ', decimalDigits: 0);
  static final _dateFormat = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final route = _routeSummary();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hire.customer?.name ?? 'Hire #${hire.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(hire: hire),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(hire.tourTypeLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  if (hire.isUpcoming) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Upcoming',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.info),
                      ),
                    ),
                  ],
                ],
              ),
              if (route != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        route,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (hire.startTime != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.schedule_rounded, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      _dateFormat.format(hire.startTime!),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _currency.format(hire.hireFullValue),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (hire.isCredit) _PaymentBadge(hire: hire),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _routeSummary() {
    if (hire.fromLocation != null && hire.toLocation != null) {
      return '${hire.fromLocation} → ${hire.toLocation}';
    }
    if (hire.stayLocations.isNotEmpty) {
      return hire.stayLocations.join(', ');
    }
    if (hire.dayLocations.isNotEmpty) {
      return hire.dayLocations.expand((day) => day).join(', ');
    }
    if (hire.package != null) {
      return hire.package;
    }
    return null;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.hire});

  final Hire hire;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (hire.status) {
      case 'completed':
        color = AppColors.success;
        break;
      case 'started':
        color = AppColors.info;
        break;
      default:
        color = AppColors.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        hire.statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.hire});

  final Hire hire;

  @override
  Widget build(BuildContext context) {
    if (hire.isFullyPaid) {
      return const _Pill(label: 'Fully Paid', color: AppColors.success, icon: Icons.check_circle_rounded);
    }
    if (hire.paymentStatus == 'partial') {
      return const _Pill(label: 'Partially Paid', color: AppColors.warning, icon: Icons.pie_chart_rounded);
    }
    return const _Pill(label: 'Unpaid', color: AppColors.danger, icon: Icons.error_outline_rounded);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.icon});

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No hires found',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary),
            ),
            SizedBox(height: 4),
            Text(
              'Try a different search or create a new hire.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
