import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_theme.dart';
import '../features/home/presentation/pages/home_page.dart';

class VividoApp extends StatelessWidget {
  const VividoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
