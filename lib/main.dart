import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MelodyFlowApp());
}

class MelodyFlowApp extends StatelessWidget {
  const MelodyFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MusicProvider(),
      child: Consumer<MusicProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: 'MelodyFlow',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.buildTheme(provider.palette, false),
            darkTheme: AppTheme.buildTheme(provider.palette, true),
            themeMode: provider.darkMode ? ThemeMode.dark : ThemeMode.light,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
