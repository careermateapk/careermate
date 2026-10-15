import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../theme/tokens.dart';
import '../../../widgets/common.dart';

/// Placeholder for tabs that are built in later steps.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: FadeSlideIn(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutBack,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: AppColors.blueTint, borderRadius: BorderRadius.circular(30)),
                  child: Icon(icon, size: 44, color: AppColors.blue),
                ),
              ),
              const SizedBox(height: 20),
              Text('Coming soon', style: AppTheme.display(context, size: 22)),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, fontSize: 15, height: 1.5)),
            ]),
          ),
        ),
      ),
    );
  }
}
