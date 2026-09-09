import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/timeline_screen.dart';
import 'services/hive_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // シードカラーを好きな色に変更可能（例: Colors.indigo, Colors.deepOrange など）
    const seedColor = Colors.teal;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'タスクタイムライン',
      // ライトモード設定
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      // ダークモード設定
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      // OSの設定に合わせて自動でライト/ダークを切り替え
      themeMode: ThemeMode.system,
      home: const TimelineScreen(),
    );
  }
}
