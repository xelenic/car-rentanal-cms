import 'package:flutter/material.dart';

import '../models/hire_page.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/hire_route_card.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Assigned Tours'),
              Tab(text: 'Unpaid Credit Hires'),
              Tab(text: 'Admin Messages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssignedToursTab(),
            _UnpaidCreditTab(),
            _AdminMessagesTab(),
          ],
        ),
      ),
    );
  }
}

class _AssignedToursTab extends StatefulWidget {
  const _AssignedToursTab();

  @override
  State<_AssignedToursTab> createState() => _AssignedToursTabState();
}

class _AssignedToursTabState extends State<_AssignedToursTab> {
  late Future<HirePage> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.fetchHires();
  }

  Future<void> _refresh() async {
    final future = ApiClient.instance.fetchHires();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.neon,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: FutureBuilder<HirePage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.neon),
            );
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load tours',
              subtitle: snapshot.error.toString(),
            );
          }

          final hires = snapshot.data!.items;

          if (hires.isEmpty) {
            return const _EmptyState(
              icon: Icons.event_busy,
              title: 'No assigned tours',
              subtitle: 'New tours assigned to you will show up here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hires.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => HireRouteCard(hire: hires[index]),
          );
        },
      ),
    );
  }
}

/// Credit hires the company hasn't fully claimed payment for yet ("Unpaid" or
/// "Partially Paid" — see Hire.isFullyPaid) — a running reminder of what's
/// still owed, whichever hire the balance happens to sit on. Claiming payment
/// itself is admin-only; this is read-only.
class _UnpaidCreditTab extends StatefulWidget {
  const _UnpaidCreditTab();

  @override
  State<_UnpaidCreditTab> createState() => _UnpaidCreditTabState();
}

class _UnpaidCreditTabState extends State<_UnpaidCreditTab> {
  late Future<HirePage> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiClient.instance.fetchHires(perPage: 50);
  }

  Future<void> _refresh() async {
    final future = ApiClient.instance.fetchHires(perPage: 50);
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.neon,
      backgroundColor: AppColors.surface,
      onRefresh: _refresh,
      child: FutureBuilder<HirePage>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.neon),
            );
          }

          if (snapshot.hasError) {
            return _EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load hires',
              subtitle: snapshot.error.toString(),
            );
          }

          final unpaid = snapshot.data!.items.where((hire) => hire.isCredit && !hire.isFullyPaid).toList();

          if (unpaid.isEmpty) {
            return const _EmptyState(
              icon: Icons.check_circle_outline,
              title: 'All credit hires are settled',
              subtitle: 'A credit hire will show up here until its payment is fully claimed.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: unpaid.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => HireRouteCard(hire: unpaid[index]),
          );
        },
      ),
    );
  }
}

class _AdminMessagesTab extends StatelessWidget {
  const _AdminMessagesTab();

  @override
  Widget build(BuildContext context) {
    return const _EmptyState(
      icon: Icons.forum_outlined,
      title: 'No messages yet',
      subtitle: 'Announcements and messages from admin will appear here.',
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 140),
      children: [
        Icon(icon, size: 48, color: AppColors.textMuted),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
