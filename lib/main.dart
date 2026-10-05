import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbit/screens/main_screen.dart';
import 'package:orbit/services/notification_service.dart';
import 'package:orbit/utils/app_theme.dart';
import 'package:orbit/utils/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Prepares the timezone database and notification plugin. Alarms are only
  // re-armed after the persisted tasks have been restored by the provider.
  NotificationService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Orbit',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const MainScreen(),
    );
  }
}
