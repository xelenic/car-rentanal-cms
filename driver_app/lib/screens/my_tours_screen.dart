import 'dart:async';

import 'package:flutter/material.dart';

import '../models/hire_tab.dart';
import '../models/tab_hires.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/tour_tabs.dart';

/// The driver's assigned tours, on their own page — what used to sit inline
/// on Home: Today, Scheduled, Completed and Cancelled, each with its first
/// few hires and a "More" button to the rest.
class MyToursScreen extends StatefulWidget {
  const MyToursScreen({super.key});

  @override
  State<MyToursScreen> createState() => _MyToursScreenState();
}

class _MyToursScreenState extends State<MyToursScreen> {
  late Future<Map<HireTab, TabHires>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<HireTab, TabHires>> _load() async {
    final results = await Future.wait([
      // Every open hire (Today and Scheduled are told apart on the phone by the
      // driver's own date), and just the first few completed / cancelled ones
      // with their exact totals — the rest is behind each tab's "More".
      ApiClient.instance.fetchHires(status: 'open'),
      ApiClient.instance.fetchHires(status: 'completed', perPage: kHomeTabLimit),
      ApiClient.instance.fetchHires(status: 'cancelled', perPage: kHomeTabLimit),
    ]);

    return buildHomeTabs(open: results[0], completed: results[1], cancelled: results[2]);
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  /// Reloads after the driver comes back from a hire or a full list — what
  /// they did there (cancelled, completed, …) moves hires between tabs.
  void _refreshQuietly() {
    if (mounted) unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tours')),
      body: RefreshIndicator(
        color: AppColors.neon,
        backgroundColor: AppColors.surface,
        onRefresh: _refresh,
        child: FutureBuilder<Map<HireTab, TabHires>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData && !snapshot.hasError) {
              return const Center(child: CircularProgressIndicator(color: AppColors.neon));
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                TourTabs(tabs: snapshot.data!, onChanged: _refreshQuietly),
              ],
            );
          },
        ),
      ),
    );
  }
}
