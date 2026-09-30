import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/vehicle.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The Add Vehicle form — or, given [vehicle], the Edit Vehicle form. Pops
/// with the created/updated [Vehicle] so the caller can reload and confirm.
class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key, this.vehicle});

  /// When set, the form edits this vehicle instead of creating a new one.
  final Vehicle? vehicle;

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _seats = TextEditingController(text: widget.vehicle?.seats.toString());
  late final _pax = TextEditingController(text: widget.vehicle?.pax.toString());
  late final _description = TextEditingController(text: widget.vehicle?.description);

  late String _condition = widget.vehicle?.condition ?? 'Good';
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.vehicle != null;

  @override
  void dispose() {
    _model.dispose();
    _seats.dispose();
    _pax.dispose();
    _description.dispose();
    super.dispose();
  }

  String? _requiredCount(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Required';
    final number = int.tryParse(text);
    if (number == null || number < 1 || number > 100) return 'Enter 1 to 100';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final vehicle = _editing
          ? await ApiClient.instance.updateVehicle(
              widget.vehicle!.id,
              model: _model.text.trim(),
              condition: _condition,
              seats: int.parse(_seats.text.trim()),
              pax: int.parse(_pax.text.trim()),
              description: _description.text,
            )
          : await ApiClient.instance.createVehicle(
              model: _model.text.trim(),
              condition: _condition,
              seats: int.parse(_seats.text.trim()),
              pax: int.parse(_pax.text.trim()),
              description: _description.text,
            );
      if (!mounted) return;
      Navigator.of(context).pop(vehicle);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Vehicle' : 'Add Vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('add-vehicle-error'),
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
              key: const Key('vehicle-model'),
              controller: _model,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Model', hintText: 'e.g. Toyota Aqua'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('vehicle-condition'),
              initialValue: _condition,
              decoration: const InputDecoration(labelText: 'Condition'),
              items: [for (final c in vehicleConditions) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (value) => setState(() => _condition = value ?? _condition),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('vehicle-seats'),
                    controller: _seats,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Seats'),
                    validator: _requiredCount,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: const Key('vehicle-pax'),
                    controller: _pax,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Passengers'),
                    validator: _requiredCount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('vehicle-description'),
              controller: _description,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-vehicle'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Vehicle'),
            ),
          ],
        ),
      ),
    );
  }
}
