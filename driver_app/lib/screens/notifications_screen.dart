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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Assigned Tours'),
              Tab(text: 'Admin Messages'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AssignedToursTab(),
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
            return const Center(
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
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}
