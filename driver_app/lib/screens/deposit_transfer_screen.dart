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

  Future<void> _pickSlipPhoto() async {
    final source = await _chooseImageSource();
    if (source == null) return;

    try {
      final photo = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      if (!mounted) return;
      setState(() => _slip = photo);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = source == ImageSource.camera
            ? 'Could not open the camera: $e'
            : 'Could not open the gallery: $e';
      });
    }
  }

  /// Lets the driver pick between the camera and their photo gallery for the
  /// bank slip, rather than forcing a fresh photo every time — some slips
  /// are already saved as a photo or screenshot from the bank's own app.
  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: AppColors.neon),
                title: const Text('Take Photo'),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: AppColors.neon),
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
                  style: TextStyle(
                    color: AppColors.neon,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Deposited Amount',
                    prefixText: 'Rs. ',
                  ),
                ),
                const SizedBox(height: 14),
                _SlipPhotoPicker(photo: _slip, onTap: _pickSlipPhoto),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? SizedBox(
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
                    style: TextStyle(color: AppColors.danger, fontSize: 12),
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
                          Icon(Icons.sync, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined, color: AppColors.neon, size: 26),
                    SizedBox(height: 6),
                    Text(
                      'Add Photo of Bank Slip',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Camera or Gallery',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
