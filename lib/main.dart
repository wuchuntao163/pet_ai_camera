import 'package:flutter/material.dart';

import 'constants/app_branding.dart';
import 'router/app_router.dart';
import 'services/app_launch.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  static final _router = createAppRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLaunch.instance.onLaunch();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppBranding.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Noto Sans SC',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFF97316)),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.black,
      ),
      routerConfig: _router,
    );
  }
}
