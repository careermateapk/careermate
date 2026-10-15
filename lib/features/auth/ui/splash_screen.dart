import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// Shown for a moment while the app checks whether the user is signed in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, s, child) => Transform.scale(scale: s, child: child),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const BrandLogo(size: 92),
            const SizedBox(height: 22),
            Text(AppConfig.appName, style: AppTheme.display(context, size: 28, color: Colors.white)),
          ]),
        ),
      ),
    );
  }
}
