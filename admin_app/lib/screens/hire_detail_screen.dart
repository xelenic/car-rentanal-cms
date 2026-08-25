import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

class HireDetailScreen extends StatefulWidget {
  const HireDetailScreen({super.key, required this.hireId});

  final int hireId;

  @override
  State<HireDetailScreen> createState() => _HireDetailScreenState();
}

class _HireDetailScreenState extends State<HireDetailScreen> {
  Hire? _hire;
  bool _loading = true;
  String? _error;

  static final _currency = NumberFormat.currency(locale: 'en_LK', symbol: 'Rs. ', decimalDigits: 2);
  static final _dateFormat = DateFormat('MMM d, y · h:mm a');

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
      final hire = await ApiClient.instance.fetchHire(widget.hireId);
      if (!mounted) return;
      setState(() => _hire = hire);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this hire. Pull down to retry.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_hire != null ? 'Hire #${_hire!.id}' : 'Hire Details')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final hire = _hire!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _headerCard(hire),
          const SizedBox(height: 12),
          _routeCard(hire),
          const SizedBox(height: 12),
          _valuesCard(hire),
          if (hire.isCredit) ...[
            const SizedBox(height: 12),
            _paymentCard(hire),
          ],
          const SizedBox(height: 12),
          _peopleCard(hire),
          if (hire.description != null && hire.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _descriptionCard(hire),
          ],
          if (hire.isTracking || hire.totalDistanceKm > 0) ...[
            const SizedBox(height: 12),
            _trackingCard(hire),
          ],
        ],
      ),
    );
  }

  Widget _headerCard(Hire hire) {
    Color statusColor;
    switch (hire.status) {
      case 'completed':
        statusColor = AppColors.success;
        break;
      case 'started':
        statusColor = AppColors.info;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    hire.customer?.name ?? 'Hire #${hire.id}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hire.statusLabel,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _infoRow(Icons.local_offer_outlined, hire.tourTypeLabel),
            if (hire.startTime != null)
              _infoRow(
                Icons.schedule_rounded,
                '${_dateFormat.format(hire.startTime!)}${hire.isUpcoming ? '  ·  Upcoming' : ''}',
              ),
            if (hire.endTime != null)
              _infoRow(Icons.event_available_rounded, 'Ends ${_dateFormat.format(hire.endTime!)}'),
            if (hire.createdAt != null)
              _infoRow(Icons.add_circle_outline_rounded, 'Created ${_dateFormat.format(hire.createdAt!)}'),
          ],
        ),
      ),
    );
  }

  Widget? _routeSummaryWidget(Hire hire) {
    if (hire.fromLocation != null && hire.toLocation != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _infoRow(Icons.trip_origin_rounded, 'From: ${hire.fromLocation}'),
          _infoRow(Icons.place_rounded, 'To: ${hire.toLocation}'),
        ],
      );
    }
    if (hire.stayLocations.isNotEmpty) {
      return _infoRow(Icons.place_outlined, hire.stayLocations.join(' → '));
    }
    if (hire.dayLocations.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < hire.dayLocations.length; i++)
            _infoRow(Icons.today_rounded, 'Day ${i + 1}: ${hire.dayLocations[i].join(' → ')}'),
        ],
      );
    }
    if (hire.package != null) {
      return _infoRow(Icons.card_giftcard_rounded, 'Package: ${hire.package}');
    }
    return null;
  }

  Widget _routeCard(Hire hire) {
    final route = _routeSummaryWidget(hire);
    if (route == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Route'),
            const SizedBox(height: 6),
            route,
          ],
        ),
      ),
    );
  }

  Widget _valuesCard(Hire hire) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Value'),
            const SizedBox(height: 10),
            _valueRow('Hire full value', _currency.format(hire.hireFullValue)),
            _valueRow('Our hire value', _currency.format(hire.ourHireValue)),
            _valueRow('Commission', _currency.format(hire.commission)),
            _valueRow('Payment type', hire.paymentTypeLabel),
          ],
        ),
      ),
    );
  }

  Widget _paymentCard(Hire hire) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _SectionTitle('Payment'),
                const Spacer(),
                if (hire.isFullyPaid)
                  const _Pill(label: 'Fully Paid', color: AppColors.success, icon: Icons.check_circle_rounded)
                else if (hire.paymentStatus == 'partial')
                  const _Pill(label: 'Partially Paid', color: AppColors.warning, icon: Icons.pie_chart_rounded)
                else
                  const _Pill(label: 'Unpaid', color: AppColors.danger, icon: Icons.error_outline_rounded),
              ],
            ),
            const SizedBox(height: 10),
            _valueRow('Paid so far', _currency.format(hire.paidAmount)),
            _valueRow('Balance remaining', _currency.format(hire.balanceRemaining)),
          ],
        ),
      ),
    );
  }

  Widget _peopleCard(Hire hire) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('People & Vehicle'),
            const SizedBox(height: 6),
            if (hire.customer != null)
              _infoRow(
                Icons.person_outline_rounded,
                hire.customer!.phone != null && hire.customer!.phone!.isNotEmpty
                    ? '${hire.customer!.name} · ${hire.customer!.phone}'
                    : hire.customer!.name,
              ),
            if (hire.driver != null)
              _infoRow(Icons.badge_outlined, 'Driver: ${hire.driver!.name}')
            else
              _infoRow(Icons.badge_outlined, 'No driver assigned'),
            if (hire.vehicle != null)
              _infoRow(Icons.directions_car_outlined, 'Vehicle: ${hire.vehicle!.model}')
            else
              _infoRow(Icons.directions_car_outlined, 'No vehicle assigned'),
          ],
        ),
      ),
    );
  }

  Widget _descriptionCard(Hire hire) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Notes'),
            const SizedBox(height: 6),
            Text(hire.description!.trim(), style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _trackingCard(Hire hire) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle('Tracking'),
            const SizedBox(height: 6),
            _infoRow(
              hire.isTracking ? Icons.podcasts_rounded : Icons.check_circle_outline_rounded,
              hire.isTracking ? 'Live — driver is currently on this hire' : 'Tracking finished',
            ),
            _infoRow(Icons.route_rounded, 'Distance covered: ${hire.totalDistanceKm.toStringAsFixed(1)} km'),
          ],
        ),
      ),
    );
  }

  Widget _valueRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
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
