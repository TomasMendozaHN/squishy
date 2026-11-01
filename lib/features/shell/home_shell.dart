import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../browser/browser_screen.dart';
import '../history/history_screen.dart';
import '../jobs/jobs_screen.dart';
import '../personalize/personalize_screen.dart';
import '../settings/settings_screen.dart';

enum HomeTab { files, squish, history, style, settings }

/// Lets any screen jump to a tab (e.g. to the queue after starting a batch).
final homeTab = ValueNotifier<int>(HomeTab.files.index);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: 1,
  );
  final _visited = <int>{};

  @override
  void initState() {
    super.initState();
    // If a queue is already running when the app opens, show it.
    if (context.scope.jobs.isBusy) homeTab.value = HomeTab.squish.index;
    _visited.add(homeTab.value);
    homeTab.addListener(_onTab);
  }

  @override
  void dispose() {
    homeTab.removeListener(_onTab);
    _fade.dispose();
    super.dispose();
  }

  void _onTab() {
    _visited.add(homeTab.value);
    _fade.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final jobs = context.scope.jobs;
    final index = homeTab.value;
    const pages = [BrowserScreen(), JobsScreen(), HistoryScreen(), PersonalizeScreen(), SettingsScreen()];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.015), end: Offset.zero)
                .animate(CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic)),
            child: IndexedStack(
              index: index,
              children: [
                // Build tabs lazily so the browser's permission check runs first.
                for (var i = 0; i < pages.length; i++)
                  _visited.contains(i) ? pages[i] : const SizedBox.shrink(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: jobs,
        builder: (context, _) {
          final active = jobs.active.length;
          return NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => homeTab.value = i,
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.video_library_outlined),
                selectedIcon: Icon(Icons.video_library_rounded),
                label: 'Files',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: active > 0,
                  label: Text('$active'),
                  backgroundColor: context.tokens.liquidA,
                  child: const Icon(Icons.water_drop_outlined),
                ),
                selectedIcon: const Icon(Icons.water_drop_rounded),
                label: 'Squish',
              ),
              const NavigationDestination(
                icon: Icon(Icons.history_rounded),
                selectedIcon: Icon(Icons.history_toggle_off_rounded),
                label: 'History',
              ),
              const NavigationDestination(
                icon: Icon(Icons.palette_outlined),
                selectedIcon: Icon(Icons.palette_rounded),
                label: 'Style',
              ),
              const NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
    );
  }
}
