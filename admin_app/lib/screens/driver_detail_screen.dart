import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/driver.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'driver_form_screen.dart';

/// One driver's details, with Edit/Delete as the signed-in user's permissions allow.
class DriverDetailScreen extends StatefulWidget {
  const DriverDetailScreen({super.key, required this.driver, this.user});

  final Driver driver;
  final AdminUser? user;

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  late Driver _driver = widget.driver;

  bool get _canEdit => widget.user?.canUpdateDrivers ?? false;
  bool get _canDelete => widget.user?.canDeleteDrivers ?? false;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Driver>(
      MaterialPageRoute(builder: (_) => DriverFormScreen(driver: _driver)),
    );
    if (updated == null || !mounted) return;

    setState(() => _driver = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} updated.')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_driver.name}"?'),
        content: const Text('This removes their account too. This can\'t be undone.'),
        actions: [
          TextButton(
            key: const Key('keep-driver'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-driver'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteDriver(_driver.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not reach the server. Nothing was deleted.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_driver.name),
        actions: [
          if (_canEdit || _canDelete)
            PopupMenuButton<String>(
              key: const Key('driver-menu'),
              tooltip: 'More',
              onSelected: (value) => value == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => [
                if (_canEdit) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (_canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Field(icon: Icons.badge_outlined, label: 'License', value: _driver.license),
          _Field(icon: Icons.call_outlined, label: 'Contact number', value: _driver.contactNumber),
          if (_driver.additionalPhoneNumber != null)
            _Field(icon: Icons.phone_forwarded_outlined, label: 'Additional phone', value: _driver.additionalPhoneNumber!),
          _Field(icon: Icons.mail_outline_rounded, label: 'Email', value: _driver.email),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
