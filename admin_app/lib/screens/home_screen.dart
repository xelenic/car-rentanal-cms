import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/initials_avatar.dart';
import 'customers_tab.dart';
import 'drivers_tab.dart';
import 'hires_screen.dart';
import 'login_screen.dart';
import 'my_expenses_screen.dart';
import 'overview_screen.dart';
import 'vehicles_dashboard_screen.dart';

class _Shortcut {
  const _Shortcut({required this.title, required this.icon, required this.color, required this.builder});

  final String title;
  final IconData icon;
  final Color color;
  final WidgetBuilder builder;
}

/// The app's home: a colorful grid of shortcuts, one per section — Overview,
/// Hires, Vehicles, Drivers, Customers, Expenses — each its own standalone
/// page one tap away, rather than tabs sharing one AppBar. Fetches the
/// signed-in user once and shares it with every section, which decides both
/// whether its shortcut shows at all (each gated on its own "view"
/// permission, except Hires — signing into the admin app already requires
/// hires.view, see Api\Admin\AuthController::login()) and what it offers
/// once opened (add, edit, delete).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  AdminUser? _user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ApiClient.instance.fetchMe();
      if (mounted) setState(() => _user = user);
    } catch (_) {
      // Shortcuts default to hidden until the user loads — a transient
      // failure here just means retrying, not a locked-out app.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Shortcut> _shortcutsFor(AdminUser user) {
    return [
      if (user.canViewDrivers)
        _Shortcut(
          title: 'Overview',
          icon: Icons.dashboard_rounded,
          color: AppColors.info,
          builder: (_) => const OverviewScreen(),
        ),
      // Always offered — logging into the admin app already requires
      // hires.view (AuthController::login()), so every signed-in user here
      // can see it.
      _Shortcut(
        title: 'Hires',
        icon: Icons.event_note_rounded,
        color: AppColors.primary,
        builder: (_) => HiresScreen(user: user),
      ),
      if (user.canViewVehicles)
        _Shortcut(
          title: 'Vehicles',
          icon: Icons.directions_car_filled_rounded,
          color: const Color(0xFFEA580C),
          builder: (_) => VehiclesDashboardScreen(user: user),
        ),
      if (user.canViewDrivers)
        _Shortcut(
          title: 'Drivers',
          icon: Icons.badge_rounded,
          color: const Color(0xFF7C3AED),
          builder: (_) => DriversTab(user: user),
        ),
      if (user.canViewCustomers)
        _Shortcut(
          title: 'Customers',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF0D9488),
          builder: (_) => CustomersTab(user: user),
        ),
      if (user.canViewMyExpenses)
        _Shortcut(
          title: 'Expenses',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFE11D48),
          builder: (_) => MyExpensesScreen(user: user),
        ),
    ];
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _open(_Shortcut shortcut) {
    Navigator.of(context).push(MaterialPageRoute(builder: shortcut.builder));
  }

  @override
  Widget build(BuildContext context) {
    final logoutButton = IconButton(
      key: const Key('logout'),
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_rounded),
      onPressed: _logout,
    );

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Rental CMS'), actions: [logoutButton]),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;
    final shortcuts = user != null ? _shortcutsFor(user) : const <_Shortcut>[];

    if (user == null || shortcuts.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Rental CMS'), actions: [logoutButton]),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              user == null
                  ? 'Could not sign you in. Check your connection and restart the app.'
                  : 'You do not have access to any section yet. Ask an admin to grant you a permission.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Car Rental CMS'), actions: [logoutButton]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: _ProfileHeader(user: user),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: shortcuts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
              ),
              itemBuilder: (context, index) {
                final shortcut = shortcuts[index];
                return _ShortcutCard(
                  key: Key('shortcut-${shortcut.title.toLowerCase()}'),
                  shortcut: shortcut,
                  onTap: () => _open(shortcut),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Greets the signed-in user by name, right above the shortcut grid — the
/// same avatar + "Welcome back" + name pattern the driver app's own home
/// screen uses.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: user.name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                user.name,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({super.key, required this.shortcut, required this.onTap});

  final _Shortcut shortcut;
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
                  color: shortcut.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(shortcut.icon, color: shortcut.color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                shortcut.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
