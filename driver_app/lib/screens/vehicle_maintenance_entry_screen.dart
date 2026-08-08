import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/vehicle.dart';
import '../models/vehicle_maintenance_record.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Add a Vehicle Service / Repair / Parts record and see the driver's past
/// entries for that type. Unlike hire expenses, these aren't tied to a
/// specific hire (just a vehicle) and are never counted toward salary.
class VehicleMaintenanceEntryScreen extends StatefulWidget {
  final String type;
  final String title;
  final IconData icon;

  const VehicleMaintenanceEntryScreen({
    super.key,
    required this.type,
    required this.title,
    required this.icon,
  });

  @override
  State<VehicleMaintenanceEntryScreen> createState() => _VehicleMaintenanceEntryScreenState();
}

class _VehicleMaintenanceEntryScreenState extends State<VehicleMaintenanceEntryScreen> {
  final _costController = TextEditingController();
  final _mileageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();

  bool get _needsMileage => widget.type == 'service';

  List<Vehicle> _vehicles = [];
  int? _vehicleId;
  XFile? _bill;

  bool _saving = false;
  bool _loading = true;
  String? _error;

  List<VehicleMaintenanceRecord> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _costController.dispose();
    _mileageController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.fetchVehicles(),
        ApiClient.instance.fetchVehicleMaintenanceRecords(type: widget.type),
      ]);
      if (!mounted) return;
      setState(() {
        _vehicles = results[0] as List<Vehicle>;
        _history = results[1] as List<VehicleMaintenanceRecord>;
        _vehicleId ??= _vehicles.isNotEmpty ? _vehicles.first.id : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      if (!mounted) return;
      setState(() => _bill = photo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera: $e');
    }
  }

  Future<void> _save() async {
    final cost = double.tryParse(_costController.text.trim());
    final mileage = _mileageController.text.trim().isEmpty
        ? null
        : int.tryParse(_mileageController.text.trim());

    if (_vehicleId == null) {
      setState(() => _error = 'Select a vehicle.');
      return;
    }
    if (cost == null || cost <= 0) {
      setState(() => _error = 'Enter a valid cost.');
      return;
    }
    if (_needsMileage && mileage == null) {
      setState(() => _error = 'Enter the current mileage.');
      return;
    }
    if (_bill == null) {
      setState(() => _error = 'Take a photo of the bill before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final bytes = await _bill!.readAsBytes();
      await ApiClient.instance.addVehicleMaintenanceRecord(
        vehicleId: _vehicleId!,
        type: widget.type,
        mileage: mileage,
        cost: cost,
        description: _descriptionController.text.trim(),
        billBytes: bytes,
        billFilename: _bill!.name,
      );
      if (!mounted) return;
      _costController.clear();
      _mileageController.clear();
      _descriptionController.clear();
      setState(() => _bill = null);
      final history = await ApiClient.instance.fetchVehicleMaintenanceRecords(type: widget.type);
      if (!mounted) return;
      setState(() => _history = history);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.title} recorded.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.neon))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
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
                        'Add ${widget.title}',
                        style: const TextStyle(
                          color: AppColors.neon,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _vehicleId,
                        isExpanded: true,
                        dropdownColor: AppColors.surfaceElevated,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(labelText: 'Vehicle'),
                        items: _vehicles
                            .map((v) => DropdownMenuItem(value: v.id, child: Text(v.model)))
                            .toList(),
                        onChanged: (value) => setState(() => _vehicleId = value),
                      ),
                      if (_needsMileage) ...[
                        const SizedBox(height: 14),
                        TextField(
                          controller: _mileageController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: AppColors.textPrimary),
                          decoration: const InputDecoration(labelText: 'Mileage', suffixText: 'km'),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        controller: _costController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(labelText: 'Cost', prefixText: '\$ '),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          labelText: 'Description (optional)',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _BillPicker(bill: _bill, onTap: _takePhoto),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onNeon,
                                  ),
                                )
                              : Text('Save ${widget.title}'),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'History',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                if (_history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No ${widget.title.toLowerCase()} recorded yet.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ..._history.map((record) => _HistoryTile(record: record)),
              ],
            ),
    );
  }
}

class _BillPicker extends StatelessWidget {
  final XFile? bill;
  final VoidCallback onTap;

  const _BillPicker({required this.bill, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: bill != null ? 160 : 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: bill != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  kIsWeb
                      ? Image.network(bill!.path, fit: BoxFit.cover)
                      : Image.file(File(bill!.path), fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Retake', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: AppColors.neon, size: 26),
                    SizedBox(height: 6),
                    Text(
                      'Take Photo of Bill',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final VehicleMaintenanceRecord record;

  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y  h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: record.billUrl != null
                ? Image.network(
                    record.billUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _billFallback(),
                  )
                : _billFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${record.cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (record.vehicleModel != null || record.mileage != null)
                  Text(
                    [
                      if (record.vehicleModel != null) record.vehicleModel!,
                      if (record.mileage != null) '${record.mileage} km',
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (record.description != null && record.description!.isNotEmpty)
                  Text(
                    record.description!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (record.createdAt != null)
                  Text(
                    dateFormat.format(record.createdAt!.toLocal()),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _billFallback() {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.receipt_long, color: AppColors.textMuted, size: 20),
    );
  }
}
