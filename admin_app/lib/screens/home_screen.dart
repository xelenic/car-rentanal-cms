import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../services/api_client.dart';
import 'customers_tab.dart';
import 'drivers_tab.dart';
import 'login_screen.dart';
import 'my_expenses_screen.dart';
import 'vehicles_dashboard_screen.dart';

class _HomeTab {
  const _HomeTab({required this.title, required this.icon, required this.body});

  final String title;
  final IconData icon;
  final Widget body;
}

/// The app's home: Vehicles / Drivers / Customers / Expenses as tabs, each
/// tab managing its own resource (add/edit/delete/view). Fetches the signed-in
/// user once and shares it with every tab, which decides both which tabs show
/// at all (each gated on its own "view" permission) and what each tab offers
/// (add, edit, delete). AppBar title and TabBar live here; each tab keeps its
/// own FloatingActionButton via a nested Scaffold.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _loading = true;
  TabController? _tabs;
  int _tabIndex = 0;
  List<_HomeTab> _visibleTabs = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final user = await ApiClient.instance.fetchMe();
      if (!mounted) return;
      final tabs = _tabsFor(user);
      setState(() {
        _visibleTabs = tabs;
        _loading = false;
      });
      _tabs = TabController(length: tabs.length, vsync: this)
        ..addListener(() {
          if (_tabs!.indexIsChanging) return;
          setState(() => _tabIndex = _tabs!.index);
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_HomeTab> _tabsFor(AdminUser user) {
    return [
      if (user.canViewVehicles)
        _HomeTab(
          title: 'Vehicles',
          icon: Icons.directions_car_filled_rounded,
          body: VehiclesDashboardScreen(user: user),
        ),
      if (user.canViewDrivers)
        _HomeTab(title: 'Drivers', icon: Icons.badge_outlined, body: DriversTab(user: user)),
      if (user.canViewCustomers)
        _HomeTab(title: 'Customers', icon: Icons.people_outline_rounded, body: CustomersTab(user: user)),
      if (user.canViewMyExpenses)
        _HomeTab(title: 'Expenses', icon: Icons.account_balance_wallet_outlined, body: MyExpensesScreen(user: user)),
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = _visibleTabs;
    final logoutButton = IconButton(
      key: const Key('logout'),
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_rounded),
      onPressed: _logout,
    );

    if (tabs.isEmpty || _tabs == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car Rental CMS'), actions: [logoutButton]),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'You do not have access to any section yet. Ask an admin to grant you a permission.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs[_tabIndex].title),
        actions: [logoutButton],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final tab in tabs)
              Tab(key: Key('home-tab-${tab.title.toLowerCase()}'), icon: Icon(tab.icon, size: 20), text: tab.title),
          ],
        ),
      ),
      body: TabBarView(controller: _tabs, children: [for (final tab in tabs) tab.body]),
    );
  }
}
