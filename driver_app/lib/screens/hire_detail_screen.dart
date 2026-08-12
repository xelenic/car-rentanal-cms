import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'expense_entry_screen.dart';
import 'placeholder_screen.dart';

class HireDetailScreen extends StatefulWidget {
  final Hire hire;

  const HireDetailScreen({super.key, required this.hire});

  @override
  State<HireDetailScreen> createState() => _HireDetailScreenState();
}

class _HireDetailScreenState extends State<HireDetailScreen> {
  late Hire _hire;
  Timer? _timer;
  bool _busy = false;
  String? _trackingError;

  static const _pingInterval = Duration(minutes: 1);

  @override
  void initState() {
    super.initState();
    _hire = widget.hire;
    if (_hire.isTracking) {
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pingInterval, (_) => _captureAndSendPoint());
  }

  Future<Position> _getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track this hire.');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  Future<void> _captureAndSendPoint() async {
    try {
      final position = await _getCurrentPosition();
      final status = await ApiClient.instance.sendTrackingPoint(
        _hire.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _hire = _hire.copyWith(totalDistanceKm: status.totalDistanceKm);
        _trackingError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    }
  }

  Future<void> _toggleTracking() async {
    if (_hire.isCompleted) return;

    setState(() {
      _busy = true;
      _trackingError = null;
    });

    try {
      if (_hire.isTracking) {
        final status = await ApiClient.instance.stopTracking(_hire.id);
        _timer?.cancel();
        if (!mounted) return;
        setState(() {
          _hire = _hire.copyWith(
            isTracking: false,
            trackingStoppedAt: status.trackingStoppedAt,
            totalDistanceKm: status.totalDistanceKm,
          );
        });
      } else {
        final position = await _getCurrentPosition();
        final status = await ApiClient.instance.startTracking(_hire.id);
        final pointStatus = await ApiClient.instance.sendTrackingPoint(
          _hire.id,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (!mounted) return;
        setState(() {
          _hire = _hire.copyWith(
            status: status.status,
            statusLabel: status.statusLabel,
            isTracking: true,
            trackingStartedAt: status.trackingStartedAt,
            totalDistanceKm: pointStatus.totalDistanceKm,
          );
        });
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Complete this hire?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This stops tracking and marks the hire as completed. It cannot be started again afterwards.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeHire();
    }
  }

  Future<void> _completeHire() async {
    setState(() {
      _busy = true;
      _trackingError = null;
    });

    try {
      final status = await ApiClient.instance.completeHire(_hire.id);
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _hire = _hire.copyWith(
          status: status.status,
          statusLabel: status.statusLabel,
          isTracking: false,
          trackingStoppedAt: status.trackingStoppedAt,
          totalDistanceKm: status.totalDistanceKm,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openShortcut(String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceholderScreen(title: title, icon: icon)),
    );
  }

  void _openExpense(String category, String title, bool receiptRequired) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          hire: _hire,
          category: category,
          title: title,
          receiptRequired: receiptRequired,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y  h:mm a');
    final hire = _hire;

    return Scaffold(
      appBar: AppBar(title: Text('Hire #${hire.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TrackingCard(
            hire: hire,
            busy: _busy,
            error: _trackingError,
            onToggle: _toggleTracking,
          ),
          const SizedBox(height: 12),
          _QuickActionsRow(
            onOpen: _openShortcut,
            onExpense: _openExpense,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Tour',
            children: [
              _InfoRow(label: 'Type', value: hire.tourTypeLabel),
              if (hire.tourType == 'package' && hire.package != null)
                _InfoRow(label: 'Package', value: hire.package!),
              if (hire.tourType != 'multi_day' && hire.tourType != 'package') ...[
                _InfoRow(label: 'From', value: hire.fromLocation ?? '—'),
                _InfoRow(label: 'To', value: hire.toLocation ?? '—'),
              ],
              if (hire.stayLocations.isNotEmpty)
                _InfoRow(
                  label: hire.tourType == 'multi_day' ? 'Locations' : 'Stay Locations',
                  value: hire.stayLocations.join(', '),
                ),
              if (hire.startTime != null)
                _InfoRow(label: 'Start', value: dateFormat.format(hire.startTime!.toLocal())),
              if (hire.endTime != null)
                _InfoRow(label: 'End', value: dateFormat.format(hire.endTime!.toLocal())),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Vehicle & Payment',
            children: [
              _InfoRow(label: 'Vehicle', value: hire.vehicle ?? '—'),
              _InfoRow(
                label: 'Total Value',
                value: 'Rs. ${hire.hireFullValue.toStringAsFixed(2)}',
              ),
              _InfoRow(label: 'Payment Method', value: hire.paymentTypeLabel),
            ],
          ),
          if (hire.description != null && hire.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Description',
              children: [
                Text(
                  hire.description!,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: _CompleteBar(
          hire: hire,
          busy: _busy,
          onComplete: _confirmComplete,
        ),
      ),
    );
  }
}

class _CompleteBar extends StatelessWidget {
  final Hire hire;
  final bool busy;
  final VoidCallback onComplete;

  const _CompleteBar({required this.hire, required this.busy, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    if (hire.isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.neon.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.neon.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.neon, size: 18),
            SizedBox(width: 8),
            Text(
              'Hire Completed',
              style: TextStyle(
                color: AppColors.neon,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final canComplete = hire.status == 'started' && !busy;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: canComplete ? onComplete : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.neon,
          foregroundColor: AppColors.onNeon,
          disabledBackgroundColor: AppColors.surfaceElevated,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          hire.status == 'started' ? 'Complete Hire' : 'Start the hire to enable completion',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _TrackingCard extends StatelessWidget {
  final Hire hire;
  final bool busy;
  final String? error;
  final VoidCallback onToggle;

  const _TrackingCard({
    required this.hire,
    required this.busy,
    required this.error,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isTracking = hire.isTracking;
    final isCompleted = hire.isCompleted;

    final String statusText;
    if (isCompleted) {
      statusText = 'Completed';
    } else if (isTracking) {
      statusText = 'Tracking active';
    } else if (hire.trackingStartedAt != null) {
      statusText = 'Tracking paused';
    } else {
      statusText = 'Not started';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isTracking) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.neon,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                statusText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PulseStartButton(
            isTracking: isTracking,
            isCompleted: isCompleted,
            busy: busy,
            distanceKm: hire.totalDistanceKm,
            onTap: onToggle,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  icon: Icons.payments_outlined,
                  label: 'Payment Method',
                  value: hire.paymentTypeLabel,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Large centered "record button"-style meter: pulses to invite a tap,
/// shows expanding ripple rings while actively tracking, and doubles as
/// the live distance readout instead of a separate stat block.
class _PulseStartButton extends StatefulWidget {
  final bool isTracking;
  final bool isCompleted;
  final bool busy;
  final double distanceKm;
  final VoidCallback onTap;

  const _PulseStartButton({
    required this.isTracking,
    required this.isCompleted,
    required this.busy,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  State<_PulseStartButton> createState() => _PulseStartButtonState();
}

class _PulseStartButtonState extends State<_PulseStartButton> with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (!widget.isCompleted) _breathController.repeat(reverse: true);
    if (widget.isTracking) _rippleController.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseStartButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isCompleted && _breathController.isAnimating) {
      _breathController.stop();
      _breathController.value = 0;
    } else if (!widget.isCompleted && !_breathController.isAnimating) {
      _breathController.repeat(reverse: true);
    }

    if (widget.isTracking && !_rippleController.isAnimating) {
      _rippleController.repeat();
    } else if (!widget.isTracking && _rippleController.isAnimating) {
      _rippleController.stop();
      _rippleController.reset();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 188.0;
    final color = widget.isCompleted ? AppColors.neon : AppColors.danger;
    final canTap = !widget.isCompleted && !widget.busy;

    return Center(
      child: GestureDetector(
        onTap: canTap ? widget.onTap : null,
        child: SizedBox(
          width: size + 56,
          height: size + 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.isTracking)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: List.generate(2, (i) {
                        final t = (_rippleController.value + (i / 2)) % 1.0;
                        return Opacity(
                          opacity: (1 - t) * 0.45,
                          child: Container(
                            width: size + t * 56,
                            height: size + t * 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.danger, width: 2),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  final scale = widget.isCompleted ? 1.0 : 1.0 + (_breathController.value * 0.045);
                  return Transform.scale(scale: scale, child: child);
                },
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.78),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.45),
                        blurRadius: 30,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: widget.busy
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.distanceKm.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'KM',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.85),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.isCompleted ? 'DONE' : (widget.isTracking ? 'STOP' : 'START'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBlock({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final void Function(String title, IconData icon) onOpen;
  final void Function(String category, String title, bool receiptRequired) onExpense;

  const _QuickActionsRow({required this.onOpen, required this.onExpense});

  static const _actions = <_ShortcutAction>[
    _ShortcutAction('Fuel', Icons.local_gas_station_outlined, 'Fuel Cost', AppColors.neon, category: 'fuel'),
    _ShortcutAction('Repair', Icons.car_repair_outlined, 'Vehicle Repair', AppColors.neon),
    _ShortcutAction('Emergency', Icons.emergency_outlined, 'Emergency', AppColors.danger),
    _ShortcutAction('Highway', Icons.toll_outlined, 'Highway Charges', AppColors.neon,
        category: 'highway', receiptRequired: false),
    _ShortcutAction('Foods', Icons.restaurant_outlined, 'Driver Foods', AppColors.neon,
        category: 'food', receiptRequired: false),
    _ShortcutAction('Rooms', Icons.hotel_outlined, 'Room Charges', AppColors.neon,
        category: 'room', receiptRequired: false),
    _ShortcutAction('Parking', Icons.local_parking_outlined, 'Parking Tickets', AppColors.neon,
        category: 'parking', receiptRequired: false),
    _ShortcutAction('Others', Icons.more_horiz_outlined, 'Others', AppColors.neon),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _QuickActionCircle(
                  icon: action.icon,
                  label: action.label,
                  color: action.color,
                  onTap: action.category != null
                      ? () => onExpense(action.category!, action.title, action.receiptRequired)
                      : () => onOpen(action.title, action.icon),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShortcutAction {
  final String label;
  final IconData icon;
  final String title;
  final Color color;
  final String? category;
  final bool receiptRequired;

  const _ShortcutAction(
    this.label,
    this.icon,
    this.title,
    this.color, {
    this.category,
    this.receiptRequired = true,
  });
}

class _QuickActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCircle({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.neon,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
