import 'package:advayx_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if we've shown permissions before
  final prefs = await SharedPreferences.getInstance();
  final permissionsShown = prefs.getBool('permissions_shown') ?? false;
  
  // Request all permissions if not shown before
  if (!permissionsShown) {
    await [
      Permission.contacts,
      Permission.phone,
      Permission.microphone,
      Permission.storage,
    ].request();
    
    await prefs.setBool('permissions_shown', true);
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: ThemeMode.system,
      home: const SplashPage(),
    );
  }
}

// Gradient Button Widget for easy reuse
class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final EdgeInsetsGeometry? padding;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.getGradientDecoration(isPrimary),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            alignment: Alignment.center,
            child: Text(
              text,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isPrimary ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}