import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/driver.dart';
import '../models/hire.dart';
import '../models/hire_page.dart';
import '../models/hire_tab.dart' show kHomeTabLimit;
import '../services/api_client.dart';
import '../services/background_tracking.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import 'hire_detail_screen.dart';
import 'login_screen.dart';
import 'my_tours_screen.dart';
import 'overview_screen.dart';
import 'salary_advance_screen.dart';
import 'salary_screen.dart';

class _HomeData {
  final Driver driver;

  /// Assigned hires the driver hasn't started yet — not scheduled-for-later
  /// vs. today, just "still waiting on you", soonest first.
  final List<Hire> pendingHires;

  const _HomeData({required this.driver, required this.pendingHires});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    // A hire may still be tracked from before the app was closed — bring the
    // background service back if the phone killed it meanwhile.
    unawaited(BackgroundTracking.ensureRunning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundTracking.ensureRunning());
    }
  }

  Future<_HomeData> _load() async {
    final results = await Future.wait([
      ApiClient.instance.fetchMe(),
      // Every open hire — pending ones are shown at the bottom of Home; all of
      // them (pending or already started) keep the background tracking
      // service in sync.
      ApiClient.instance.fetchHires(status: 'open'),
    ]);

    final driver = results[0] as Driver;
    final open = results[1] as HirePage;

    // The server's own list of hires being tracked is the source of truth —
    // re-attach the background service to any it doesn't already cover.
    unawaited(BackgroundTracking.resume(open.items.where((h) => h.isTracking).map((h) => h.id)));

    final pending = open.items.where((h) => h.status == 'pending').toList()
      ..sort((a, b) {
        final aStart = a.startTime, bStart = b.startTime;
        if (aStart == null && bStart == null) return 0;
        if (aStart == null) return 1; // unscheduled after scheduled
        if (bStart == null) return -1;
        return aStart.compareTo(bStart);
      });

    return _HomeData(driver: driver, pendingHires: pending);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  /// Reloads after the driver comes back from one of the quick-access pages —
  /// a hire may have been started, completed or cancelled there, which the
  /// background tracking service needs to know about.
  void _refreshQuietly() {
    if (mounted) unawaited(_refresh());
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    _refreshQuietly();
  }

  Future<void> _logout() async {
    // Signing out ends any background tracking first — the pings would only
    // start failing with 401s once the token is gone.
    await BackgroundTracking.stopAll();
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
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.neon,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<_HomeData>(
            future: _future,
            builder: (context, snapshot) {
              // While reloading, the previous data stays on screen (a snapshot
              // keeps it until the new future completes); only a first load —
              // with nothing to show yet — is a bare spinner.
              if (!snapshot.hasData && !snapshot.hasError) {
                return Center(
                  child: CircularProgressIndicator(color: AppColors.neon),
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
                  children: [
                    Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _ProfileHeader(driver: data.driver, onLogout: _logout),
                  const SizedBox(height: 28),
                  _QuickAccessGrid(
                    onOverview: () => _open(const OverviewScreen()),
                    onMyTours: () => _open(const MyToursScreen()),
                    onSalary: () => _open(const SalaryScreen()),
                    onSalaryAdvance: () => _open(const SalaryAdvanceScreen()),
                  ),
                  _PendingHiresSection(hires: data.pendingHires, onReturn: _refreshQuietly),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Driver driver;
  final VoidCallback onLogout;

  const _ProfileHeader({required this.driver, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: driver.name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                driver.name,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onLogout,
          icon: Icon(Icons.logout, color: AppColors.textSecondary),
          tooltip: 'Logout',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// The four shortcuts that used to be spread across the Home screen (the big
/// Overview card, the tour tabs) and Options (Salary, Salary Advance) — now
/// one animated 2x2 grid, so Home opens straight to a clean, glanceable menu.
class _QuickAccessGrid extends StatefulWidget {
  final VoidCallback onOverview;
  final VoidCallback onMyTours;
  final VoidCallback onSalary;
  final VoidCallback onSalaryAdvance;

  const _QuickAccessGrid({
    required this.onOverview,
    required this.onMyTours,
    required this.onSalary,
    required this.onSalaryAdvance,
  });

  @override
  State<_QuickAccessGrid> createState() => _QuickAccessGridState();
}

class _QuickAccessGridState extends State<_QuickAccessGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickAccessItem(
        title: 'Overview',
        subtitle: 'Full monthly summary',
        icon: Icons.dashboard_rounded,
        color: AppColors.neon,
        onTap: widget.onOverview,
      ),
      _QuickAccessItem(
        title: 'My Tours',
        subtitle: 'Assigned tours',
        icon: Icons.map_rounded,
        color: AppColors.success,
        onTap: widget.onMyTours,
      ),
      _QuickAccessItem(
        title: 'Salary',
        subtitle: 'This month\'s pay',
        icon: Icons.payments_rounded,
        color: const Color(0xFFF59E0B),
        onTap: widget.onSalary,
      ),
      _QuickAccessItem(
        title: 'Salary Advance',
        subtitle: 'Request an advance',
        icon: Icons.request_quote_rounded,
        color: const Color(0xFF8B5CF6),
        onTap: widget.onSalaryAdvance,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.neon.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.grid_view_rounded, color: AppColors.neon, size: 15),
            ),
            const SizedBox(width: 10),
            Text(
              'Quick Access',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            // A staggered fade-and-rise entrance: each card starts its climb a
            // little after the one before it, so the grid feels like it's
            // settling into place rather than just appearing.
            final start = index * 0.12;
            final animation = CurvedAnimation(
              parent: _controller,
              curve: Interval(start, (start + 0.55).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
            );

            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                return Opacity(
                  opacity: animation.value,
                  child: Transform.translate(
                    offset: Offset(0, 24 * (1 - animation.value)),
                    child: child,
                  ),
                );
              },
              child: _QuickAccessCard(item: items[index]),
            );
          },
        ),
      ],
    );
  }
}

class _QuickAccessCard extends StatefulWidget {
  final _QuickAccessItem item;

  const _QuickAccessCard({required this.item});

  @override
  State<_QuickAccessCard> createState() => _QuickAccessCardState();
}

class _QuickAccessCardState extends State<_QuickAccessCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: item.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [item.color.withValues(alpha: 0.85), item.color],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: item.color.withValues(alpha: 0.32),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(item.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hires waiting for the driver to hit Start — the one thing left on Home
/// besides the quick-access shortcuts, called out in red since these are the
/// hires that actually need the driver to do something. Empty entirely once
/// there is nothing pending, rather than an empty-state box taking up room.
class _PendingHiresSection extends StatelessWidget {
  final List<Hire> hires;

  /// Called after the driver comes back from a pending hire's own screen —
  /// starting or cancelling it moves it out of this list.
  final VoidCallback onReturn;

  const _PendingHiresSection({required this.hires, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    if (hires.isEmpty) return const SizedBox.shrink();

    final shown = hires.take(kHomeTabLimit).toList();
    final remaining = hires.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.pending_actions_rounded, color: AppColors.danger, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Pending Hires',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${hires.length}',
                style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Padding(
          padding: EdgeInsets.only(left: 40),
          child: Text(
            'Waiting on you to start',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
          ),
        ),
        const SizedBox(height: 14),
        for (final hire in shown) ...[
          _PendingHireTile(hire: hire, onReturn: onReturn),
          const SizedBox(height: 10),
        ],
        if (remaining > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+$remaining more in My Tours',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

class _PendingHireTile extends StatelessWidget {
  final Hire hire;
  final VoidCallback onReturn;

  const _PendingHireTile({required this.hire, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final scheduled = hire.startTime != null
        ? DateFormat('MMM d, h:mm a').format(hire.startTime!.toLocal())
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => HireDetailScreen(hire: hire)),
          );
          onReturn();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.danger.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hire.tourTypeLabel,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hire.routeSummary,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (scheduled != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        scheduled,
                        style: TextStyle(color: AppColors.danger, fontSize: 10.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.danger, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
