import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'custom_theme_screen.dart';

/// Lets the driver pick which theme the app uses. Defaults to
/// [ThemeController.instance] — the same singleton [main.dart] listens to,
/// so picking a theme here updates the whole app immediately. Only tests
/// pass a different one, to avoid touching real secure storage.
class AppearanceScreen extends StatelessWidget {
  final ThemeController? controller;

  const AppearanceScreen({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    final themeController = controller ?? ThemeController.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: AnimatedBuilder(
        animation: themeController,
        builder: (context, _) {
          final active = themeController.variant;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final variant in AppThemeVariant.values) ...[
                _ThemeTile(
                  variant: variant,
                  palette: variant == AppThemeVariant.custom ? themeController.customPalette : variant.presetPalette!,
                  selected: variant == active,
                  onTap: () => themeController.setVariant(variant),
                  onEdit: variant == AppThemeVariant.custom
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute<void>(builder: (_) => CustomThemeScreen(controller: themeController)),
                          )
                      : null,
                ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppThemeVariant variant;
  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  /// Only Custom has this — opens the color editor instead of just
  /// selecting the theme.
  final VoidCallback? onEdit;

  const _ThemeTile({
    required this.variant,
    required this.palette,
    required this.selected,
    required this.onTap,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? palette.neon : AppColors.border, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              _Swatch(palette: palette),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  variant.label,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                  tooltip: 'Edit colors',
                ),
              if (selected)
                Icon(Icons.check_circle, color: palette.neon, size: 22)
              else
                Icon(Icons.circle_outlined, color: AppColors.textMuted, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small preview of a theme's look: its background behind its accent and
/// surface colors, so the driver can tell themes apart before picking one.
class _Swatch extends StatelessWidget {
  final AppPalette palette;

  const _Swatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: palette.neon, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: palette.surface,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
          ),
        ],
      ),
    );
  }
}
