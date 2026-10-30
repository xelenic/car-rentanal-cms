import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/driver.dart';
import '../models/driver_summary.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/driver_deposit_tab.dart';
import '../widgets/driver_expenses_tab.dart';
import '../widgets/hire_history_tab.dart';
import '../widgets/state_views.dart';
import 'driver_form_screen.dart';

/// One grid item on a driver's page — tapping it opens that section as its
/// own standalone page, rather than switching an in-place tab.
class _DriverSection {
  const _DriverSection({required this.key, required this.label, required this.icon, required this.color});

  final String key;
  final String label;
  final IconData icon;
  final Color color;
}

/// One driver's details — a grid menu of sections (Overview, Details, Hires,
/// Expenses, Deposit), each its own standalone page one tap away, the same
/// shortcut-grid pattern HomeScreen uses for its own top-level sections.
class DriverDetailScreen extends StatefulWidget {
  const DriverDetailScreen({super.key, required this.driver, this.user});

  final Driver driver;
  final AdminUser? user;

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  late Driver _driver = widget.driver;

  bool get _canEdit => widget.user?.canUpdateDrivers ?? false;
  bool get _canDelete => widget.user?.canDeleteDrivers ?? false;

  /// Built fresh on every build (not cached) so its colors always reflect
  /// whichever theme is active right now — see AppColors in theme/app_theme.dart.
  List<_DriverSection> get _sections => [
        _DriverSection(key: 'overview', label: 'Overview', icon: Icons.dashboard_rounded, color: AppColors.info),
        _DriverSection(key: 'details', label: 'Details', icon: Icons.contact_page_outlined, color: const Color(0xFF7C3AED)),
        _DriverSection(key: 'hires', label: 'Hires', icon: Icons.event_note_rounded, color: AppColors.primary),
        _DriverSection(key: 'expenses', label: 'Expenses', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFFE11D48)),
        _DriverSection(key: 'deposit', label: 'Deposit', icon: Icons.savings_rounded, color: const Color(0xFF0D9488)),
      ];

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Driver>(
      MaterialPageRoute(builder: (_) => DriverFormScreen(driver: _driver)),
    );
    if (updated == null || !mounted) return;

    setState(() => _driver = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} updated.')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_driver.name}"?'),
        content: const Text('This removes their account too. This can\'t be undone.'),
        actions: [
          TextButton(
            key: const Key('keep-driver'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-driver'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteDriver(_driver.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not reach the server. Nothing was deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_driver.name),
        actions: [
          if (_canEdit || _canDelete)
            PopupMenuButton<String>(
              key: const Key('driver-menu'),
              tooltip: 'More',
              onSelected: (value) => value == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => [
                if (_canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (_canDelete)
                  PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
              ],
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _sections.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.05,
        ),
        itemBuilder: (context, index) {
          final section = _sections[index];
          return _SectionCard(
            key: Key('section-${section.key}'),
            section: section,
            onTap: () => _open(section),
          );
        },
      ),
    );
  }

  void _open(_DriverSection section) {
    final Widget page = switch (section.key) {
      'overview' => _DriverOverviewTab(driverId: _driver.id),
      'details' => _buildDetails(),
      'hires' => HireHistoryTab(driverId: _driver.id, user: widget.user),
      'expenses' => DriverExpensesTab(driverId: _driver.id, user: widget.user),
      'deposit' => DriverDepositTab(driverId: _driver.id),
      _ => const SizedBox.shrink(),
    };

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${section.label} · ${_driver.name}')),
        body: page,
      ),
    ));
  }

  Widget _buildDetails() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Field(icon: Icons.badge_outlined, label: 'License', value: _driver.license),
        _Field(icon: Icons.call_outlined, label: 'Contact number', value: _driver.contactNumber),
        if (_driver.additionalPhoneNumber != null)
          _Field(icon: Icons.phone_forwarded_outlined, label: 'Additional phone', value: _driver.additionalPhoneNumber!),
        _Field(icon: Icons.mail_outline_rounded, label: 'Email', value: _driver.email),
      ],
    );
  }
}

/// One grid tile on a driver's page — same look as HomeScreen's own
/// shortcut cards, so a driver's page reads as "one level deeper" in the
/// same navigation style, not a different pattern.
class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.section, required this.onTap});

  final _DriverSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(section.icon, color: section.color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                section.label,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This driver's Overview tab: one month's earnings at a time — current
/// month to start, stepped back and forward like the Hires tab's own month
/// bar (see HireHistoryTab).
class _DriverOverviewTab extends StatefulWidget {
  const _DriverOverviewTab({required this.driverId});

  final int driverId;

  @override
  State<_DriverOverviewTab> createState() => _DriverOverviewTabState();
}

class _DriverOverviewTabState extends State<_DriverOverviewTab> with AutomaticKeepAliveClientMixin {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  DriverSummary? _summary;
  bool _loading = true;
  String? _error;

  static final _monthLabel = DateFormat('MMMM y');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final summary = await ApiClient.instance.fetchDriverSummary(widget.driverId, year: _year, month: _month);
      if (mounted) setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
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
                key: const Key('driver-overview-month-prev'),
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
                key: const Key('driver-overview-month-next'),
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

    final summary = _summary!;
    final loss = summary.salaryPayable < 0;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            key: const Key('driver-overview-salary'),
            color: AppColors.primary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Salary Payable · ${countOf(summary.hireCount, 'hire')}',
                      style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  if (summary.payrollStatus != null) ...[
                    _PayrollStatusPill(status: summary.payrollStatus!),
                    const SizedBox(width: 8),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatRsExact(summary.salaryPayable),
                      key: const Key('driver-overview-salary-value'),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: loss ? const Color(0xFFFFC9C9) : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DriverStatTile(
                    label: 'Full Value',
                    value: formatRsShort(summary.hireFullValueTotal),
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFB3810A),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DriverStatTile(
                    label: 'Our Hire Value',
                    value: formatRsShort(summary.ourHireValueTotal),
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF2A78D6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DriverStatTile(
                    label: 'Commission',
                    value: formatRsShort(summary.commissionTotal),
                    icon: Icons.percent_rounded,
                    color: const Color(0xFF158F66),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DriverStatTile(
                    label: 'Expenses',
                    value: formatRsShort(summary.expensesTotal),
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PayrollStatusPill extends StatelessWidget {
  const _PayrollStatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = status == 'paid' ? 'Paid' : 'Finalized';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

class _DriverStatTile extends StatelessWidget {
  const _DriverStatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
