import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Records a driver's cash deposit for a month: the amount handed over to
/// the company plus a photo of the bank slip as evidence.
class DepositTransferScreen extends StatefulWidget {
  final int year;
  final int month;
  final String monthLabel;
  final double suggestedAmount;

  const DepositTransferScreen({
    super.key,
    required this.year,
    required this.month,
    required this.monthLabel,
    required this.suggestedAmount,
  });

  @override
  State<DepositTransferScreen> createState() => _DepositTransferScreenState();
}

class _DepositTransferScreenState extends State<DepositTransferScreen> {
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _slip;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedAmount > 0) {
      _amountController.text = widget.suggestedAmount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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
      setState(() => _slip = photo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera: $e');
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid deposited amount.');
      return;
    }
    if (_slip == null) {
      setState(() => _error = 'Take a photo of the bank slip before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final bytes = await _slip!.readAsBytes();
      await ApiClient.instance.addDepositTransfer(
        year: widget.year,
        month: widget.month,
        amount: amount,
        slipBytes: bytes,
        slipFilename: _slip!.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Transfer Deposit')),
      body: ListView(
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
                  'Deposit for ${widget.monthLabel} ${widget.year}',
                  style: const TextStyle(
                    color: AppColors.neon,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Deposited Amount',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 14),
                _SlipPhotoPicker(photo: _slip, onTap: _takePhoto),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onNeon,
                            ),
                          )
                        : const Text('Submit Transfer'),
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
        ],
      ),
    );
  }
}

class _SlipPhotoPicker extends StatelessWidget {
  final XFile? photo;
  final VoidCallback onTap;

  const _SlipPhotoPicker({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: photo != null ? 160 : 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  kIsWeb
                      ? Image.network(photo!.path, fit: BoxFit.cover)
                      : Image.file(File(photo!.path), fit: BoxFit.cover),
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
                      'Take Photo of Bank Slip',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
