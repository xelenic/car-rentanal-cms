import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/hire.dart';
import '../screens/hire_detail_screen.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'hire_card.dart';
import 'state_views.dart';

/// One driver's or one customer's hires, one month at a time — current month
/// to start, stepped back and forward like the Expenses page's own month
/// bar. The total up top covers every hire the month matched, not just the
/// page shown. Pass exactly one of [driverId]/[customerId].
class HireHistoryTab extends StatefulWidget {
  const HireHistoryTab({super.key, this.driverId, this.customerId, this.user})
      : assert(
          (driverId == null) != (customerId == null),
          'Pass exactly one of driverId or customerId.',
        );

  final int? driverId;
  final int? customerId;
  final AdminUser? user;

  @override
  State<HireHistoryTab> createState() => _HireHistoryTabState();
}

class _HireHistoryTabState extends State<HireHistoryTab> with AutomaticKeepAliveClientMixin {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  List<Hire> _hires = [];
  HireListSummary _summary = const HireListSummary();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// Bumped on every fresh load, so a slow answer for a month that has since
  /// been stepped away from can't overwrite a newer one.
  int _generation = 0;

  static final _monthLabel = DateFormat('MMMM y');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _monthStart => DateTime(_year, _month, 1);
  DateTime get _monthEnd => DateTime(_year, _month + 1, 0);

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.instance.fetchHires(
        driverId: widget.driverId,
        customerId: widget.customerId,
        dateFrom: _monthStart,
        dateTo: _monthEnd,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _hires = page.hires;
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
      final page = await ApiClient.instance.fetchHires(
        driverId: widget.driverId,
        customerId: widget.customerId,
        dateFrom: _monthStart,
        dateTo: _monthEnd,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = _hires.map((h) => h.id).toSet();
      setState(() {
        _hires = [..._hires, ...page.hires.where((h) => !known.contains(h.id))];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _stepMonth(int by) {
    final moved = DateTime(_year, _month + by);
    setState(() {
      _year = moved.year;
      _month = moved.month;
    });
    _load();
  }

  Future<void> _open(Hire hire) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: hire.id, user: widget.user)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                key: const Key('hire-history-month-prev'),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _stepMonth(-1),
              ),
              Expanded(
                child: Text(
                  _monthLabel.format(DateTime(_year, _month)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
              ),
              IconButton(
                key: const Key('hire-history-month-next'),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _stepMonth(1),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '${countOf(_summary.count, 'hire')} · ${formatRsShort(_summary.hireFullValueTotal)} total · '
              '${formatRsShort(_summary.ourHireValueTotal)} our value · ${formatRsShort(_summary.commissionTotal)} commission',
              key: const Key('hire-history-summary'),
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_hires.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'No hires this month',
                  message: 'Nothing recorded for ${_monthLabel.format(DateTime(_year, _month))}.',
                ),
              )
            else ...[
              for (final hire in _hires) ...[
                HireCard(hire: hire, onTap: () => _open(hire)),
                const SizedBox(height: 10),
              ],
              if (_hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
