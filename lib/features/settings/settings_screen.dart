import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../../widgets/common.dart';
import '../../widgets/squishy_logo.dart';
import '../folder_picker/folder_picker_screen.dart';
import '../welcome/permissions_panel.dart';
import '../welcome/welcome_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.scope;
    final s = scope.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.only(bottom: SquishyTokens.space7),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space4, 0),
            child: Text('Settings', style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SectionHeader('Compression defaults'),
          _Group(children: [
            _Labeled(
              title: 'Default quality',
              child: SegmentedButton<Quality>(
                segments: [for (final q in Quality.values) ButtonSegment(value: q, label: Text(q.label))],
                selected: {s.quality},
                onSelectionChanged: (v) => s.quality = v.first,
              ),
            ),
            _Labeled(
              title: 'Codec',
              subtitle: scope.device.hevc ? null : "This phone has no H.265 encoder",
              child: SegmentedButton<VideoCodec>(
                segments: [
                  for (final c in VideoCodec.values)
                    ButtonSegment(
                      value: c,
                      enabled: c != VideoCodec.hevc || scope.device.hevc,
                      label: Text('${c.label} · ${c.hint}'),
                    ),
                ],
                selected: {scope.device.hevc ? s.codec : VideoCodec.avc},
                onSelectionChanged: (v) => s.codec = v.first,
              ),
            ),
            _Labeled(
              title: 'Videos at the same time',
              subtitle: '1 = one after another. Phones rarely go faster above 2.',
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 2, label: Text('2')),
                  ButtonSegment(value: 3, label: Text('3')),
                ],
                selected: {s.parallel},
                onSelectionChanged: (v) {
                  s.parallel = v.first;
                  SquishyNative.setParallel(v.first);
                },
              ),
            ),
            SwitchListTile(
              value: s.deleteOriginals,
              onChanged: (v) => s.deleteOriginals = v,
              title: const Text('Delete originals automatically'),
              subtitle: const Text('Permanently, only after the compressed copy is verified'),
            ),
            SwitchListTile(
              value: s.keepScreenOn,
              onChanged: (v) => s.keepScreenOn = v,
              title: const Text('Keep screen on while squishing'),
              subtitle: const Text('Only while Squishy is open. Work continues with the screen off either way.'),
            ),
            ListTile(
              title: const Text('Save compressed videos to'),
              subtitle: Text(s.customOutputDir ?? '"compressed" folder next to each original'),
              trailing: s.customOutputDir == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Back to default',
                      icon: const Icon(Icons.restart_alt_rounded),
                      onPressed: () => s.customOutputDir = null,
                    ),
              onTap: () async {
                final picked = await Navigator.of(context).push<String>(
                  MaterialPageRoute(builder: (_) => const FolderPickerScreen()),
                );
                if (picked != null) s.customOutputDir = picked;
              },
            ),
          ]),
          const SectionHeader('Files'),
          _Group(children: [
            SwitchListTile(
              value: s.showHidden,
              onChanged: (v) => s.showHidden = v,
              title: const Text('Show hidden folders'),
            ),
          ]),
          SectionHeader(
            'Background reliability',
            subtitle: scope.device.isXiaomi ? 'Xiaomi phones need the extra switches below' : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
            child: PermissionsPanel(),
          ),
          const SectionHeader('About'),
          _Group(children: [
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snap) => ListTile(
                leading: const SquishyLogo(size: 40, showArrows: false),
                title: const Text('Squishy'),
                subtitle: Text(
                  'Version ${snap.data?.version ?? '…'} · ${scope.device.manufacturer} ${scope.device.model}, Android API ${scope.device.sdk}',
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.auto_awesome_rounded),
              title: Text('Vibecoded'),
              subtitle: Text('Designed and written with an AI coding assistant (Claude), steered by Tomas.'),
            ),
            ListTile(
              leading: const Icon(Icons.replay_rounded),
              title: const Text('Show welcome again'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WelcomeScreen())),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: SquishyTokens.space2),
        child: Column(children: children),
      ),
    );
  }
}

class _Labeled extends StatelessWidget {
  const _Labeled({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4, vertical: SquishyTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.text.bodyLarge),
          if (subtitle != null)
            Text(subtitle!, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
          const SizedBox(height: SquishyTokens.space2),
          SizedBox(width: double.infinity, child: child),
        ],
      ),
    );
  }
}
