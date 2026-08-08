import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const InitialsAvatar({super.key, required this.name, this.size = 48});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0].toUpperCase());
    final initials = letters.join();
    return initials.isEmpty ? '?' : initials;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neon, AppColors.neonDeep],
        ),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: AppColors.onNeon,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}
