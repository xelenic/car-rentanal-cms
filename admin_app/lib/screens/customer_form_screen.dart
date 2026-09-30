import 'package:flutter/material.dart';

import '../models/customer.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The Add Customer form — or, given [customer], the Edit Customer form.
class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key, this.customer});

  final Customer? customer;

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.customer?.name);
  late final _phone = TextEditingController(text: widget.customer?.phone);
  late final _email = TextEditingController(text: widget.customer?.email);
  late final _nicPassport = TextEditingController(text: widget.customer?.nicPassport);
  late final _address = TextEditingController(text: widget.customer?.address);
  late final _notes = TextEditingController(text: widget.customer?.notes);

  bool _submitting = false;
  String? _error;

  bool get _editing => widget.customer != null;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _nicPassport.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _required(String? value) => (value ?? '').trim().isEmpty ? 'Required' : null;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final customer = await ApiClient.instance.saveCustomer(
        id: widget.customer?.id,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text,
        nicPassport: _nicPassport.text,
        address: _address.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(customer);
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
      appBar: AppBar(title: Text(_editing ? 'Edit Customer' : 'Add Customer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('customer-form-error'),
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
              key: const Key('customer-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-phone'),
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-nic'),
              controller: _nicPassport,
              decoration: const InputDecoration(labelText: 'NIC / Passport (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-address'),
              controller: _address,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('customer-notes'),
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-customer'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
