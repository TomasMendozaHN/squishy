import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/native.dart';
import '../../widgets/common.dart';

/// Checklist of everything Squishy needs to browse files and never get killed.
/// Re-checks itself whenever the user comes back from a settings screen.
class PermissionsPanel extends StatefulWidget {
  const PermissionsPanel({super.key, this.onStorageChanged});

  final ValueChanged<bool>? onStorageChanged;

  @override
  State<PermissionsPanel> createState() => _PermissionsPanelState();
}

class _PermissionsPanelState extends State<PermissionsPanel> with WidgetsBindingObserver {
  bool _storage = false;
  bool _notifications = false;
  bool _battery = false;
  bool _autostartOpened = false;
  bool _saverOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final storage = await Permission.manageExternalStorage.isGranted;
    final notifications = await Permission.notification.isGranted;
    final battery = await Permission.ignoreBatteryOptimizations.isGranted;
    if (!mounted) return;
    setState(() {
      _storage = storage;
      _notifications = notifications;
      _battery = battery;
    });
    widget.onStorageChanged?.call(storage);
  }

  @override
  Widget build(BuildContext context) {
    final xiaomi = context.scope.device.isXiaomi;
    final items = [
      _Item(
        icon: Icons.folder_open_rounded,
        title: 'All files access',
        body: 'Browse every folder, save next to the original and delete it when done. Required.',
        done: _storage,
        onTap: () async {
          await Permission.manageExternalStorage.request();
          _refresh();
        },
      ),
      _Item(
        icon: Icons.notifications_active_rounded,
        title: 'Notifications',
        body: 'Shows live progress while Squishy works in the background.',
        done: _notifications,
        onTap: () async {
          await Permission.notification.request();
          _refresh();
        },
      ),
      _Item(
        icon: Icons.battery_charging_full_rounded,
        title: 'Unrestricted battery',
        body: 'Stops Android from pausing long batches.',
        done: _battery,
        onTap: () async {
          await SquishyNative.requestIgnoreBatteryOptimizations();
        },
      ),
      if (xiaomi) ...[
        _Item(
          icon: Icons.rocket_launch_rounded,
          title: 'Xiaomi: Autostart',
          body: 'HyperOS/MIUI kills apps without it. Turn Squishy ON in the list.',
          done: _autostartOpened,
          doneLabel: 'Opened',
          onTap: () async {
            await SquishyNative.openAutostart();
            setState(() => _autostartOpened = true);
          },
        ),
        _Item(
          icon: Icons.bolt_rounded,
          title: 'Xiaomi: Battery saver',
          body: 'Pick "No restrictions" for Squishy.',
          done: _saverOpened,
          doneLabel: 'Opened',
          onTap: () async {
            await SquishyNative.openBatterySaver();
            setState(() => _saverOpened = true);
          },
        ),
      ],
    ];
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: SquishyTokens.space3),
            child: items[i],
          ).animate(delay: (80 * i).ms).fadeIn(duration: context.tokens.medium).slideX(begin: 0.06, end: 0),
        if (xiaomi)
          Text(
            'Tip: also lock Squishy in Recents (swipe down on its card) so cleaning '
            'Recents never closes it.',
            style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    required this.body,
    required this.done,
    required this.onTap,
    this.doneLabel = 'Granted',
  });

  final IconData icon;
  final String title;
  final String body;
  final bool done;
  final String doneLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      onTap: done ? null : onTap,
      child: Row(
        children: [
          AnimatedContainer(
            duration: t.medium,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: done ? null : t.liquidGradient,
              color: done ? t.success.withValues(alpha: 0.18) : null,
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Icon(
              done ? Icons.check_rounded : icon,
              color: done ? t.success : context.colors.surface,
            ),
          ),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: SquishyTokens.space2),
          done ? Pill(doneLabel, color: t.success) : const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
