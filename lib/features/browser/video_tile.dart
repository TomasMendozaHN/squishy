import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/scope.dart';
import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/settings.dart';
import '../../widgets/common.dart';

class VideoThumb extends StatelessWidget {
  const VideoThumb({super.key, required this.path, this.radius});

  final String path;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final placeholder = Container(
      color: context.colors.onSurface.withValues(alpha: 0.06),
      child: Icon(Icons.movie_rounded, color: context.colors.onSurface.withValues(alpha: 0.25)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius ?? t.radiusSm),
      child: FutureBuilder<String?>(
        future: context.scope.probes.thumbnail(path),
        builder: (context, snap) {
          final file = snap.data;
          if (file == null) {
            return snap.connectionState == ConnectionState.done
                ? placeholder
                : placeholder.animate(onPlay: (c) => c.repeat()).shimmer(
                      duration: 1200.ms,
                      color: context.colors.onSurface.withValues(alpha: 0.08),
                    );
          }
          return Image.file(
            File(file),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            frameBuilder: (context, child, frame, sync) => sync
                ? child
                : AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: t.medium,
                    child: child,
                  ),
          );
        },
      ),
    );
  }
}

/// One video in the browser, rendered for the chosen [ViewMode].
class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.file,
    required this.mode,
    required this.selected,
    required this.selecting,
    required this.onTap,
    required this.onLongPress,
  });

  final VideoFile file;
  final ViewMode mode;
  final bool selected;
  final bool selecting;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final probes = context.scope.probes;
    return ListenableBuilder(
      listenable: probes,
      builder: (context, _) {
        final info = probes.info(file.path);
        return switch (mode) {
          ViewMode.grid => _grid(context, info),
          ViewMode.cards => _card(context, info),
          ViewMode.list => _list(context, info),
          ViewMode.compact => _compact(context, info),
        };
      },
    );
  }

  String _meta(VideoInfo? info, {bool withDate = false}) => [
        formatBytes(file.sizeBytes),
        if (info != null) info.resolutionLabel,
        if (withDate) formatDate(file.modified),
      ].join(' · ');

  Widget _check(BuildContext context) {
    final t = context.tokens;
    return AnimatedScale(
      scale: selecting ? 1 : 0,
      duration: t.fast,
      curve: Curves.easeOutBack,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: selected ? t.liquidGradient : null,
          color: selected ? null : context.colors.surface.withValues(alpha: 0.7),
          border: Border.all(color: selected ? Colors.transparent : context.colors.onSurface.withValues(alpha: 0.4), width: 2),
        ),
        child: selected ? Icon(Icons.check_rounded, size: 16, color: context.colors.surface) : null,
      ),
    );
  }

  Widget _durationBadge(BuildContext context, VideoInfo? info) {
    if (info == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.colors.scrim.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        formatDuration(info.durationMs),
        // Always light text: it sits on a dark scrim over the thumbnail.
        style: context.text.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _grid(BuildContext context, VideoInfo? info) {
    return GlassCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(SquishyTokens.space1 + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumb(path: file.path),
                Positioned(right: 6, bottom: 6, child: _durationBadge(context, info)),
                Positioned(left: 6, top: 6, child: _check(context)),
              ],
            ),
          ),
          const SizedBox(height: SquishyTokens.space1 + 2),
          Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.labelMedium),
          Text(
            formatBytes(file.sizeBytes),
            style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, VideoInfo? info) {
    return GlassCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(SquishyTokens.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumb(path: file.path, radius: context.tokens.radiusMd),
                Positioned(right: 8, bottom: 8, child: _durationBadge(context, info)),
                Positioned(left: 8, top: 8, child: _check(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SquishyTokens.space2, SquishyTokens.space2, SquishyTokens.space2, SquishyTokens.space1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _meta(info, withDate: true),
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _list(BuildContext context, VideoInfo? info) {
    return GlassCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(SquishyTokens.space2),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 60,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoThumb(path: file.path),
                Positioned(right: 4, bottom: 4, child: _durationBadge(context, info)),
              ],
            ),
          ),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(
                  _meta(info),
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                Text(
                  formatDate(file.modified),
                  style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _check(context),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context, VideoInfo? info) {
    return GlassCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space3, vertical: SquishyTokens.space2),
      child: Row(
        children: [
          Icon(Icons.play_circle_outline_rounded, color: context.tokens.liquidA),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
          ),
          Text(
            [formatBytes(file.sizeBytes), if (info != null) formatDuration(info.durationMs)].join(' · '),
            style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
          ),
          const SizedBox(width: SquishyTokens.space2),
          _check(context),
        ],
      ),
    );
  }
}

class FolderTile extends StatelessWidget {
  const FolderTile({super.key, required this.path, required this.onTap, this.dense = false});

  final String path;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final name = path.split('/').last;
    final highlight = name.toLowerCase() == 'compressed';
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: SquishyTokens.space3, vertical: SquishyTokens.space3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (highlight ? t.success : t.liquidA).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Icon(
              highlight ? Icons.folder_zip_rounded : Icons.folder_rounded,
              color: highlight ? t.success : t.liquidA,
              size: 20,
            ),
          ),
          const SizedBox(width: SquishyTokens.space3),
          Expanded(
            child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
          ),
          if (highlight) Pill('output', color: t.success),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );
  }
}
