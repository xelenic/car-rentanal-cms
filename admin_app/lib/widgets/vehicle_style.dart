import 'package:flutter/material.dart';

import '../models/hire_tab.dart';
import '../theme/app_theme.dart';

/// The colour a vehicle's condition is shown in.
Color conditionColor(String condition) => switch (condition) {
      'New' || 'Excellent' => AppColors.success,
      'Good' => AppColors.info,
      'Fair' => AppColors.warning,
      'Poor' => AppColors.danger,
      _ => AppColors.textSecondary,
    };

/// The colour each hire tab is shown in, in its tab bar badge.
Color hireTabColor(HireTab tab) => switch (tab) {
      HireTab.all => AppColors.textSecondary,
      HireTab.today => AppColors.primary,
      HireTab.scheduled => AppColors.info,
      HireTab.completed => AppColors.success,
      HireTab.cancelled => AppColors.danger,
    };
