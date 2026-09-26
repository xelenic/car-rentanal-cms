import 'package:flutter/material.dart';

import '../models/admin_user.dart';
import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/state_views.dart';

/// Adding, renaming and deleting the categories expenses are filed under.
/// Which of those is offered follows what the user may do; a category with
/// expenses filed under it can be renamed but not deleted.
class ExpenseCategoriesScreen extends StatefulWidget {
  const ExpenseCategoriesScreen({super.key, required this.user});

  final AdminUser user;

  @override
  State<ExpenseCategoriesScreen> createState() => _ExpenseCategoriesScreenState();
}

class _ExpenseCategoriesScreenState extends State<ExpenseCategoriesScreen> {
  final _newName = TextEditingController();

  List<ExpenseCategory> _categories = [];
  bool _loading = true;
  bool _adding = false;
  String? _error;
  String? _addError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newName.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final categories = await ApiClient.instance.fetchExpenseCategories();
      if (mounted) setState(() => _categories = categories);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _add() async {
    final name = _newName.text.trim();
    if (name.isEmpty) {
      setState(() => _addError = 'Type a name first');
      return;
    }

    setState(() {
      _adding = true;
      _addError = null;
    });

    try {
      final created = await ApiClient.instance.createExpenseCategory(name);
      if (!mounted) return;
      _newName.clear();
      _snack('${created.name} added.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _addError = e.message);
    } catch (_) {
      if (mounted) setState(() => _addError = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _rename(ExpenseCategory category) async {
    final renamed = await showDialog<ExpenseCategory>(
      context: context,
      builder: (_) => _RenameDialog(category: category),
    );
    if (renamed == null || !mounted) return;

    _snack('Renamed to ${renamed.name}.');
    await _load(silent: true);
  }

  Future<void> _delete(ExpenseCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('Nothing is filed under it, so no expenses are affected.'),
        actions: [
          TextButton(
            key: const Key('keep-category'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-category'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteExpenseCategory(category.id);
      if (!mounted) return;
      _snack('${category.name} deleted.');
      await _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Could not reach the server. Nothing was deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expense Categories')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          if (widget.user.canCreateMyExpenses) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('category-name-field'),
                    controller: _newName,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _add(),
                    decoration: InputDecoration(
                      hintText: 'New category, e.g. Bank charges',
                      counterText: '',
                      errorText: _addError,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('add-category'),
                    onPressed: _adding ? null : _add,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          if (_categories.isEmpty)
            const EmptyState(
              icon: Icons.sell_outlined,
              title: 'No categories yet',
              message: 'Add one to start filing expenses under it.',
            )
          else
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _categories.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    _tile(_categories[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),
          const Text(
            'Renaming a category renames it on every expense filed under it. '
            'A category can only be deleted once nothing is filed under it.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _tile(ExpenseCategory category) {
    return ListTile(
      key: Key('category-${category.key}'),
      title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
      subtitle: Text(
        countOf(category.expensesCount, 'expense'),
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.user.canUpdateMyExpenses)
            IconButton(
              key: Key('rename-${category.key}'),
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _rename(category),
            ),
          if (widget.user.canDeleteMyExpenses)
            IconButton(
              key: Key('delete-${category.key}'),
              tooltip: category.isInUse ? 'In use — move or delete its expenses first' : 'Delete',
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: category.isInUse ? AppColors.textMuted : AppColors.danger,
              ),
              // Disabled while expenses are filed under it — the server would refuse anyway.
              onPressed: category.isInUse ? null : () => _delete(category),
            ),
        ],
      ),
    );
  }
}

/// Renames a category, keeping the dialog open with the reason if the name is refused.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.category});

  final ExpenseCategory category;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _name = TextEditingController(text: widget.category.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Type a name');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final renamed = await ApiClient.instance.renameExpenseCategory(widget.category.id, name);
      if (mounted) Navigator.of(context).pop(renamed);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename category'),
      content: TextField(
        key: const Key('rename-field'),
        controller: _name,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.words,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(errorText: _error),
      ),
      actions: [
        TextButton(
          key: const Key('cancel-rename'),
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('save-rename'),
          onPressed: _saving ? null : _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
