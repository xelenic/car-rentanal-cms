import 'package:flutter/material.dart';

import '../models/driver.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The Add Driver form — or, given [driver], the Edit Driver form. A driver
/// is also a User with the Driver role (ApiClient.saveDriver handles that),
/// so a password is required when adding and optional when editing.
class DriverFormScreen extends StatefulWidget {
  const DriverFormScreen({super.key, this.driver});

  final Driver? driver;

  @override
  State<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends State<DriverFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.driver?.name);
  late final _license = TextEditingController(text: widget.driver?.license);
  late final _contactNumber = TextEditingController(text: widget.driver?.contactNumber);
  late final _additionalPhone = TextEditingController(text: widget.driver?.additionalPhoneNumber);
  late final _email = TextEditingController(text: widget.driver?.email);
  final _password = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  bool get _editing => widget.driver != null;

  @override
  void dispose() {
    _name.dispose();
    _license.dispose();
    _contactNumber.dispose();
    _additionalPhone.dispose();
    _email.dispose();
    _password.dispose();
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
      final driver = await ApiClient.instance.saveDriver(
        id: widget.driver?.id,
        name: _name.text.trim(),
        license: _license.text.trim(),
        contactNumber: _contactNumber.text.trim(),
        additionalPhoneNumber: _additionalPhone.text,
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(driver);
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
      appBar: AppBar(title: Text(_editing ? 'Edit Driver' : 'Add Driver')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('driver-form-error'),
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
              key: const Key('driver-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('driver-license'),
              controller: _license,
              decoration: const InputDecoration(labelText: 'License number'),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('driver-contact'),
              controller: _contactNumber,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Contact number'),
              validator: _required,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('driver-additional-phone'),
              controller: _additionalPhone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Additional phone (optional)'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('driver-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Required';
                if (!text.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('driver-password'),
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: _editing ? 'New password (optional)' : 'Password',
                helperText: _editing ? 'Leave blank to keep the current password.' : 'At least 8 characters.',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                final text = value ?? '';
                if (!_editing && text.isEmpty) return 'Required';
                if (text.isNotEmpty && text.length < 8) return 'At least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-driver'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Driver'),
            ),
          ],
        ),
      ),
    );
  }
}
