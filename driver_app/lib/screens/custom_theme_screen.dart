import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../theme/app_theme.dart';

/// Lets the driver set every color of their own "Custom" theme one at a
/// time. Editing a color here switches the app to Custom immediately — see
/// [ThemeController.updateCustomPalette].
class CustomThemeScreen extends StatelessWidget {
  final ThemeController? controller;

  const CustomThemeScreen({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = controller ?? ThemeController.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Theme'),
        actions: [
          IconButton(
            onPressed: () => _confirmReset(context, themeController),
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reset to Sky Blue',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          final palette = themeController.customPalette;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final group in paletteGroups) ...[
                Text(
                  group.title,
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < group.fields.length; i++) ...[
                        if (i > 0) Divider(color: AppColors.border, height: 1),
                        _ColorRow(
                          field: group.fields[i],
                          color: group.fields[i].read(palette),
                          onTap: () => _pickColor(context, themeController, group.fields[i]),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickColor(BuildContext context, ThemeController controller, PaletteField field) async {
    var picked = field.read(controller.customPalette);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(field.label, style: TextStyle(color: AppColors.textPrimary)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: picked,
            onColorChanged: (color) => picked = color,
            enableAlpha: false,
            hexInputBar: true,
            labelTypes: const [],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Select'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.updateCustomPalette((current) => field.write(current, picked));
    }
  }

  Future<void> _confirmReset(BuildContext context, ThemeController controller) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Reset custom colors?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'This replaces every custom color with Sky Blue\'s. It only affects the Custom theme — the other themes are unchanged.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.resetCustomPalette();
    }
  }
}

class _ColorRow extends StatelessWidget {
  final PaletteField field;
  final Color color;
  final VoidCallback onTap;

  const _ColorRow({required this.field, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hex = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                field.label,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13.5),
              ),
            ),
            Text(hex, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
