import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The add / edit revenue-from-another-company form, with an optional bank
/// slip photo as proof of the credited amount. Pops with the saved
/// [OtherCompanyRevenue].
class RevenueFormScreen extends StatefulWidget {
  const RevenueFormScreen({super.key, required this.initialDate, this.revenue});

  /// The date a new entry starts on (ignored when editing).
  final DateTime initialDate;

  /// The entry being edited; null when adding one.
  final OtherCompanyRevenue? revenue;

  @override
  State<RevenueFormScreen> createState() => _RevenueFormScreenState();
}

class _RevenueFormScreenState extends State<RevenueFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _hire = TextEditingController(text: widget.revenue?.hire ?? '');
  late final _bookingNumber = TextEditingController(text: widget.revenue?.bookingNumber ?? '');
  late final _vehicle = TextEditingController(text: widget.revenue?.vehicle ?? '');
  late final _fullAmount = TextEditingController(text: widget.revenue == null ? '' : _plain(widget.revenue!.fullAmount));
  late final _creditedAmount = TextEditingController(text: widget.revenue == null ? '' : _plain(widget.revenue!.creditedAmount));
  late final _balance = TextEditingController(text: widget.revenue == null ? '' : _plain(widget.revenue!.balance));
  late final _vehicleAmount = TextEditingController(text: widget.revenue == null ? '' : _plain(widget.revenue!.vehicleAmount));

  late DateTime _date = widget.revenue?.date ?? widget.initialDate;

  final _picker = ImagePicker();
  XFile? _newSlip;

  bool _submitting = false;
  String? _error;

  static final _dateFormat = DateFormat('EEE, MMM d, y');

  bool get _editing => widget.revenue != null;

  /// 1500.0 -> "1500", 1500.5 -> "1500.5".
  static String _plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _hire.dispose();
    _bookingNumber.dispose();
    _vehicle.dispose();
    _fullAmount.dispose();
    _creditedAmount.dispose();
    _balance.dispose();
    _vehicleAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickSlipPhoto() async {
    final source = await _chooseImageSource();
    if (source == null) return;

    try {
      final photo = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 85);
      if (photo == null || !mounted) return;
      setState(() => _newSlip = photo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = source == ImageSource.camera ? 'Could not open the camera: $e' : 'Could not open the gallery: $e');
    }
  }

  /// Lets the admin pick between the camera and their photo gallery for the
  /// bank slip — some slips are already saved as a photo or a screenshot
  /// from the bank's own app.
  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final slipBytes = _newSlip != null ? await _newSlip!.readAsBytes() : null;
      final saved = await ApiClient.instance.saveOtherCompanyRevenue(
        id: widget.revenue?.id,
        hire: _hire.text.trim(),
        bookingNumber: _bookingNumber.text.trim(),
        vehicle: _vehicle.text.trim(),
        fullAmount: _fullAmount.text.trim(),
        creditedAmount: _creditedAmount.text.trim(),
        balance: _balance.text.trim(),
        vehicleAmount: _vehicleAmount.text.trim(),
        date: _date,
        slipBytes: slipBytes,
        slipFilename: _newSlip?.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _requiredValidator(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;

  String? _amountValidator(String? value, {bool allowNegative = false}) {
    final amount = double.tryParse((value ?? '').trim());
    if (amount == null) return 'Enter an amount';
    if (!allowNegative && amount < 0) return 'Cannot be negative';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Revenue' : 'Add Revenue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('revenue-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('revenue-hire'),
              controller: _hire,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Hire', hintText: 'e.g. Colombo to Kandy'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-booking-number'),
              controller: _bookingNumber,
              decoration: const InputDecoration(labelText: 'Booking Number', hintText: "Their booking reference"),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-vehicle'),
              controller: _vehicle,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Vehicle', hintText: 'e.g. Toyota Aqua — ABC-1234'),
              validator: _requiredValidator,
            ),
            const SizedBox(height: 14),
            InkWell(
              key: const Key('revenue-date'),
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.event_rounded, size: 18),
                  helperText: "Counts toward this date's month.",
                ),
                child: Text(_dateFormat.format(_date), style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-full-amount'),
              controller: _fullAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Full Amount (Rs.)'),
              validator: _amountValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-credited-amount'),
              controller: _creditedAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Credited Amount (Rs.)', helperText: 'Counts toward My Profit.'),
              validator: _amountValidator,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-balance'),
              controller: _balance,
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
              decoration: const InputDecoration(labelText: 'Balance (Rs.)'),
              validator: (value) => _amountValidator(value, allowNegative: true),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('revenue-vehicle-amount'),
              controller: _vehicleAmount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Vehicle Amount (Rs.)'),
              validator: _amountValidator,
            ),
            const SizedBox(height: 20),
            Text('BANK SLIP (OPTIONAL)', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            _SlipPicker(newPhoto: _newSlip, existingUrl: widget.revenue?.slipUrl, onTap: _pickSlipPhoto),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-revenue'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Revenue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A photo of the bank slip — a newly picked one takes priority over the
/// slip the entry already had, which stays shown (and stays on the server)
/// until a new one is picked.
class _SlipPicker extends StatelessWidget {
  const _SlipPicker({required this.newPhoto, required this.existingUrl, required this.onTap});

  final XFile? newPhoto;
  final String? existingUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = newPhoto != null || existingUrl != null;

    return InkWell(
      key: const Key('slip-picker'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: hasPhoto ? 160 : 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: hasPhoto ? _photo() : _placeholder(),
      ),
    );
  }

  Widget _photo() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (newPhoto != null)
          kIsWeb ? Image.network(newPhoto!.path, fit: BoxFit.cover) : Image.file(File(newPhoto!.path), fit: BoxFit.cover)
        else
          Image.network(
            existingUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: AppColors.surfaceElevated,
              child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted)),
            ),
          ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sync, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 26),
          const SizedBox(height: 6),
          Text('Add Photo of Bank Slip', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(height: 2),
          Text('Camera or Gallery', style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
        ],
      ),
    );
  }
}
