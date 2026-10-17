import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'providers/music_provider.dart';
import 'screens/home_screen.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  // 初始化后台播放与通知栏控制（必须在 runApp 之前）。
  // 处理器单例保存在 audio_handler.audioServiceHandler 中，
  // MusicProvider 装配时会读取它，把播放状态同步到通知栏与锁屏控制。
  await setupAudioService();

  // 音频会话：处理音频焦点、耳机拔出自动暂停等系统行为
  await initAudioSession();

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
