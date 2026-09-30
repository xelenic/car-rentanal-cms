import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/customer.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import 'customer_form_screen.dart';

/// One customer's details, with Edit/Delete as the signed-in user's permissions allow.
class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({super.key, required this.customer, this.user});

  final Customer customer;
  final AdminUser? user;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer = widget.customer;

  bool get _canEdit => widget.user?.canUpdateCustomers ?? false;
  bool get _canDelete => widget.user?.canDeleteCustomers ?? false;

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Customer>(
      MaterialPageRoute(builder: (_) => CustomerFormScreen(customer: _customer)),
    );
    if (updated == null || !mounted) return;

    setState(() => _customer = updated);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${updated.name} updated.')));
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${_customer.name}"?'),
        content: const Text('This can\'t be undone.'),
        actions: [
          TextButton(
            key: const Key('keep-customer'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-customer'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteCustomer(_customer.id);
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
        title: Text(_customer.name),
        actions: [
          if (_canEdit || _canDelete)
            PopupMenuButton<String>(
              key: const Key('customer-menu'),
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
          _Field(icon: Icons.call_outlined, label: 'Phone', value: _customer.phone),
          if (_customer.email != null) _Field(icon: Icons.mail_outline_rounded, label: 'Email', value: _customer.email!),
          if (_customer.nicPassport != null)
            _Field(icon: Icons.badge_outlined, label: 'NIC / Passport', value: _customer.nicPassport!),
          if (_customer.address != null)
            _Field(icon: Icons.location_on_outlined, label: 'Address', value: _customer.address!),
          if (_customer.notes != null) _Field(icon: Icons.sticky_note_2_outlined, label: 'Notes', value: _customer.notes!),
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
