import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/scope.dart';
import 'app/theme.dart';
import 'app/theme_presets.dart';
import 'core/history_controller.dart';
import 'core/jobs_controller.dart';
import 'core/native.dart';
import 'core/probe_cache.dart';
import 'core/settings.dart';
import 'features/splash/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final settings = await AppSettings.load();
  final device = await SquishyNative.deviceInfo();
  final jobs = JobsController(settings);
  runApp(AppScope(
    settings: settings,
    jobs: jobs,
    history: HistoryController(jobs),
    probes: ProbeCache(),
    device: device,
    child: const SquishyApp(),
  ));
}

class SquishyApp extends StatelessWidget {
  const SquishyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.scope.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        ThemeData themeFor(Brightness b) => buildTheme(
              palette: settings.themePreset.palette(b),
              corners: settings.corners,
              font: settings.font,
              reduceMotion: settings.reduceMotion,
            );
        final follow = settings.themePreset == ThemePreset.followSystem;
        final fixed = settings.themePreset.palette(Brightness.dark).brightness;
        return MaterialApp(
          title: 'Squishy',
          debugShowCheckedModeBanner: false,
          theme: themeFor(follow ? Brightness.light : fixed),
          darkTheme: themeFor(follow ? Brightness.dark : fixed),
          themeMode: follow
              ? ThemeMode.system
              : fixed == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
          home: const SplashScreen(),
        );
      },
    );
  }
}
