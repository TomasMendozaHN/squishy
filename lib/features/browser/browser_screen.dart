import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../widgets/common.dart';
import '../../widgets/share_actions.dart';
import '../../widgets/squishy_logo.dart';
import '../compress/compress_sheet.dart';
import '../editor/segment_editor_screen.dart';
import 'browser_controller.dart';
import 'video_tile.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> with WidgetsBindingObserver {
  BrowserController? _c;
  bool? _granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_granted != true) {
        _checkPermission();
      } else {
        _c?.refresh();
      }
    }
  }

  Future<void> _checkPermission() async {
    final granted = await Permission.manageExternalStorage.isGranted;
    if (!mounted) return;
    setState(() => _granted = granted);
    if (granted && _c == null) {
      final scope = context.scope;
      _c = BrowserController(scope.settings, scope.probes)..init();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_granted == false) {
      return EmptyState(
        icon: const SquishyLogo(size: 110),
        title: 'Let me peek at your videos',
        message: 'Squishy needs "All files access" to browse folders and replace originals.',
        action: GradientButton(
          label: 'Grant access',
          icon: Icons.folder_open_rounded,
          expand: false,
          onPressed: () async {
            await Permission.manageExternalStorage.request();
            _checkPermission();
          },
        ),
      );
    }
    final c = _c;
    if (c == null) return const Center(child: CircularProgressIndicator());
    return ListenableBuilder(
      listenable: Listenable.merge([c, context.scope.settings]),
      builder: (context, _) => PopScope(
        canPop: !c.selecting && !c.canGoUp,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          c.selecting ? c.clearSelection() : c.up();
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: c.refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  _AppBar(controller: c),
                  SliverToBoxAdapter(child: _QuickRow(controller: c)),
                  SliverToBoxAdapter(child: _Crumbs(controller: c)),
                  ..._content(context, c),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              ),
            ),
            Positioned(
              left: SquishyTokens.space4,
              right: SquishyTokens.space4,
              bottom: SquishyTokens.space4,
              child: _SelectionBar(controller: c),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, BrowserController c) {
    if (c.loading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: SquishyLogo(size: 72)),
        ),
      ];
    }
    if (c.error != null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icon(Icons.lock_rounded, size: 64, color: context.tokens.danger),
            title: "Can't open this folder",
            message: c.error!,
          ),
        ),
      ];
    }
    if (c.folders.isEmpty && c.videos.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            icon: Icon(Icons.videocam_off_rounded, size: 64, color: context.tokens.liquidA),
            title: 'No videos here',
            message: 'Try another folder or one of the shortcuts above.',
          ),
        ),
      ];
    }
    final mode = context.scope.settings.viewMode;
    return [
      if (c.folders.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
          sliver: SliverList.separated(
            itemCount: c.folders.length,
            separatorBuilder: (_, _) => const SizedBox(height: SquishyTokens.space2),
            itemBuilder: (context, i) => FolderTile(
              path: c.folders[i],
              onTap: () => c.open(c.folders[i]),
            ).animate().fadeIn(duration: context.tokens.medium, delay: (20 * i.clamp(0, 12)).ms).slideX(begin: 0.04, end: 0),
          ),
        ),
      if (c.videos.isNotEmpty)
        SliverToBoxAdapter(
          child: SectionHeader(
            '${c.videos.length} video${c.videos.length == 1 ? '' : 's'}',
            subtitle: '${formatBytes(c.videos.fold(0, (s, v) => s + v.sizeBytes))} · sorted by ${context.scope.settings.sortField.label.toLowerCase()}',
            trailing: TextButton(onPressed: c.selectAll, child: const Text('Select all')),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
        sliver: SliverLayoutBuilder(builder: (context, constraints) {
          final w = constraints.crossAxisExtent;
          Widget tile(int i) {
            final v = c.videos[i];
            return VideoTile(
              file: v,
              mode: mode,
              selected: c.selected.contains(v.path),
              selecting: c.selecting,
              onTap: () => c.selecting ? c.toggle(v.path) : _showActions(v),
              onLongPress: () => c.toggle(v.path),
            ).animate().fadeIn(duration: context.tokens.medium, delay: (25 * i.clamp(0, 16)).ms).scaleXY(begin: 0.96, end: 1);
          }

          return switch (mode) {
            ViewMode.grid => SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (w / 130).floor().clamp(2, 6),
                  mainAxisSpacing: SquishyTokens.space2,
                  crossAxisSpacing: SquishyTokens.space2,
                  childAspectRatio: 0.78,
                ),
                itemCount: c.videos.length,
                itemBuilder: (_, i) => tile(i),
              ),
            ViewMode.cards => SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: (w / 380).ceil().clamp(1, 3),
                  mainAxisSpacing: SquishyTokens.space3,
                  crossAxisSpacing: SquishyTokens.space3,
                  mainAxisExtent: (w / (w / 380).ceil().clamp(1, 3)) * 9 / 16 + 74,
                ),
                itemCount: c.videos.length,
                itemBuilder: (_, i) => tile(i),
              ),
            ViewMode.list || ViewMode.compact => SliverList.separated(
                itemCount: c.videos.length,
                separatorBuilder: (_, _) => SizedBox(height: mode == ViewMode.list ? SquishyTokens.space2 : SquishyTokens.space1 + 2),
                itemBuilder: (_, i) => tile(i),
              ),
          };
        }),
      ),
    ];
  }

  void _showActions(VideoFile v) {
    final probes = context.scope.probes;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: probes,
        builder: (context, _) {
          final info = probes.info(v.path);
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.25),
                    child: AspectRatio(aspectRatio: 16 / 9, child: VideoThumb(path: v.path, radius: context.tokens.radiusMd)),
                  ),
                  const SizedBox(height: SquishyTokens.space3),
                  Text(v.name, style: context.text.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: SquishyTokens.space1),
                  Wrap(
                    spacing: SquishyTokens.space2,
                    runSpacing: SquishyTokens.space1,
                    children: [
                      Pill(formatBytes(v.sizeBytes), icon: Icons.sd_storage_rounded),
                      if (info != null) ...[
                        Pill(formatDuration(info.durationMs), icon: Icons.timer_rounded),
                        Pill('${info.displayWidth}×${info.displayHeight}', icon: Icons.aspect_ratio_rounded),
                        if (info.bitrate > 0) Pill('${(info.bitrate / 1e6).toStringAsFixed(1)} Mbps', icon: Icons.speed_rounded),
                      ],
                    ],
                  ),
                  const SizedBox(height: SquishyTokens.space4),
                  GradientButton(
                    label: 'Squish this video',
                    icon: Icons.compress_rounded,
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      showCompressSheet(this.context, [v]);
                    },
                  ),
                  const SizedBox(height: SquishyTokens.space2),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      Navigator.of(this.context).push(MaterialPageRoute(builder: (_) => SegmentEditorScreen(file: v)));
                    },
                    icon: const Icon(Icons.content_cut_rounded),
                    label: const Text('Cut segments'),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _c?.toggle(v.path);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Select'),
                  ),
                  const SizedBox(height: SquishyTokens.space2),
                  ShareActions(path: v.path),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final settings = context.scope.settings;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 110,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      surfaceTintColor: Colors.transparent,
      leading: controller.canGoUp
          ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: controller.up)
          : const Padding(padding: EdgeInsets.all(10), child: SquishyLogo(size: 34, playing: false, showArrows: false)),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsetsDirectional.only(start: 64, bottom: 14),
        title: Text(
          controller.dir == controller.root?.path ? 'Your videos' : controller.dir?.split('/').last ?? '',
          style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      actions: [
        if (controller.roots.length > 1)
          PopupMenuButton(
            icon: const Icon(Icons.sd_card_rounded),
            tooltip: 'Storage',
            itemBuilder: (_) => [
              for (final r in controller.roots) PopupMenuItem(value: r, child: Text(r.label)),
            ],
            onSelected: controller.switchRoot,
          ),
        IconButton(
          tooltip: 'Sort',
          icon: const Icon(Icons.swap_vert_rounded),
          onPressed: () => _showSort(context, settings),
        ),
        IconButton(
          tooltip: 'View',
          icon: Icon(switch (settings.viewMode) {
            ViewMode.grid => Icons.grid_view_rounded,
            ViewMode.cards => Icons.view_agenda_rounded,
            ViewMode.list => Icons.view_list_rounded,
            ViewMode.compact => Icons.reorder_rounded,
          }),
          onPressed: () => _showView(context, settings),
        ),
      ],
    );
  }

  void _showSort(BuildContext context, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Sort videos by', style: context.text.titleLarge),
                const SizedBox(height: SquishyTokens.space3),
                for (final f in SortField.values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SquishyTokens.space2),
                    child: GlassCard(
                      selected: settings.sortField == f,
                      onTap: () => settings.sortField = f,
                      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4, vertical: SquishyTokens.space3),
                      child: Row(
                        children: [
                          Icon(switch (f) {
                            SortField.name => Icons.sort_by_alpha_rounded,
                            SortField.date => Icons.event_rounded,
                            SortField.size => Icons.sd_storage_rounded,
                            SortField.duration => Icons.timer_rounded,
                            SortField.resolution => Icons.high_quality_rounded,
                          }),
                          const SizedBox(width: SquishyTokens.space3),
                          Expanded(child: Text(f.label, style: context.text.titleSmall)),
                          if (settings.sortField == f) Icon(Icons.check_rounded, color: context.colors.primary),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: SquishyTokens.space2),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, icon: Icon(Icons.arrow_upward_rounded), label: Text('Ascending')),
                    ButtonSegment(value: false, icon: Icon(Icons.arrow_downward_rounded), label: Text('Descending')),
                  ],
                  selected: {settings.sortAscending},
                  onSelectionChanged: (s) => settings.sortAscending = s.first,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showView(BuildContext context, AppSettings settings) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, 0, SquishyTokens.space4, SquishyTokens.space4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Show videos as', style: context.text.titleLarge),
                const SizedBox(height: SquishyTokens.space3),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  mainAxisSpacing: SquishyTokens.space2,
                  crossAxisSpacing: SquishyTokens.space2,
                  childAspectRatio: 1.25,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final m in ViewMode.values)
                      ViewModePreviewCard(mode: m, selected: settings.viewMode == m, onTap: () => settings.viewMode = m),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mini mock-up of a [ViewMode], used here and on the Personalization screen.
class ViewModePreviewCard extends StatelessWidget {
  const ViewModePreviewCard({super.key, required this.mode, required this.selected, required this.onTap});

  final ViewMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final block = context.colors.onSurface.withValues(alpha: 0.10);
    Widget thumb([double? w, double? h]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [t.liquidA.withValues(alpha: 0.6), t.liquidB.withValues(alpha: 0.6)]),
            borderRadius: BorderRadius.circular(4),
          ),
        );
    Widget line(double w) => Container(
          width: w,
          height: 5,
          decoration: BoxDecoration(color: block, borderRadius: BorderRadius.circular(3)),
        );
    final preview = switch (mode) {
      ViewMode.grid => GridView.count(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          physics: const NeverScrollableScrollPhysics(),
          children: List.generate(6, (_) => thumb()),
        ),
      ViewMode.cards => Column(
          children: [
            Expanded(child: thumb(double.infinity)),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerLeft, child: line(60)),
          ],
        ),
      ViewMode.list => Column(
          children: [
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [thumb(30, 18), const SizedBox(width: 6), line(50)]),
              ),
          ],
        ),
      ViewMode.compact => Column(
          children: [
            for (var i = 0; i < 5; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: t.liquidA, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  line(70),
                ]),
              ),
          ],
        ),
    };
    return GlassCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(SquishyTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: preview),
          const SizedBox(height: SquishyTokens.space2),
          Text(mode.label, style: context.text.titleSmall),
          Text(mode.hint, style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _QuickRow extends StatelessWidget {
  const _QuickRow({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.availableQuick.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
        itemCount: controller.availableQuick.length,
        separatorBuilder: (_, _) => const SizedBox(width: SquishyTokens.space2),
        itemBuilder: (context, i) {
          final q = controller.availableQuick[i];
          final active = controller.dir == '${controller.root?.path}/${q.relative}';
          return FilterChip(
            selected: active,
            label: Text(q.label),
            avatar: Icon(switch (q.label) {
              'Camera' => Icons.photo_camera_rounded,
              'Screen recordings' => Icons.screenshot_monitor_rounded,
              'Downloads' => Icons.download_rounded,
              'Movies' => Icons.movie_rounded,
              _ => Icons.chat_bubble_rounded,
            }, size: 18),
            onSelected: (_) => controller.openQuick(q),
          );
        },
      ),
    );
  }
}

class _Crumbs extends StatelessWidget {
  const _Crumbs({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final crumbs = controller.crumbs;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space4),
        itemCount: crumbs.length,
        separatorBuilder: (_, _) => Icon(Icons.chevron_left_rounded, size: 16, color: context.colors.onSurfaceVariant),
        itemBuilder: (context, i) {
          final (label, path) = crumbs[crumbs.length - 1 - i];
          final last = i == 0;
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: last ? null : () => controller.open(path),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  label,
                  style: context.text.labelLarge?.copyWith(
                    color: last ? context.colors.primary : context.colors.onSurfaceVariant,
                    fontWeight: last ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.controller});

  final BrowserController controller;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = controller.selected.length;
    return AnimatedSlide(
      offset: controller.selecting ? Offset.zero : const Offset(0, 1.6),
      duration: t.medium,
      curve: Curves.easeOutBack,
      child: AnimatedOpacity(
        opacity: controller.selecting ? 1 : 0,
        duration: t.fast,
        child: Container(
          padding: const EdgeInsets.all(SquishyTokens.space2),
          decoration: BoxDecoration(
            color: context.colors.inverseSurface,
            borderRadius: BorderRadius.circular(t.radiusLg),
            boxShadow: [BoxShadow(color: context.colors.shadow.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: controller.clearSelection,
                icon: Icon(Icons.close_rounded, color: context.colors.onInverseSurface),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$n selected', style: context.text.titleSmall?.copyWith(color: context.colors.onInverseSurface)),
                    Text(
                      formatBytes(controller.selectedBytes),
                      style: context.text.labelSmall?.copyWith(color: context.colors.onInverseSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              GradientButton(
                label: 'Squish',
                icon: Icons.compress_rounded,
                expand: false,
                onPressed: n == 0 ? null : () => showCompressSheet(context, controller.selectedFiles, onStarted: controller.clearSelection),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
