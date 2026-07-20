import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BATTLE',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                color: AppColors.gold,
                fontSize: 48,
              ),
            ),
            Text(
              'GRAF',
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                color: AppColors.brightRed,
                fontSize: 64,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
