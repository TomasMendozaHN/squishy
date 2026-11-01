import 'dart:io';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../app/theme_presets.dart';
import '../core/native.dart';

Future<void> playVideo(BuildContext context, String path) async {
  if (!File(path).existsSync()) {
    _missing(context);
    return;
  }
  final ok = await SquishyNative.openVideo(path);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No video player found')));
  }
}

void _missing(BuildContext context) => ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This file was moved or deleted')),
    );

/// WhatsApp (always first), Gmail, Play and the system share sheet for one video.
class ShareActions extends StatelessWidget {
  const ShareActions({super.key, required this.path, this.showPlay = true});

  final String path;
  final bool showPlay;

  Future<void> _share(BuildContext context, String target) async {
    if (!File(path).existsSync()) {
      _missing(context);
      return;
    }
    await SquishyNative.shareVideo(path, target);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    Widget brand(String label, IconData icon, Color color, String target) => Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: ShareColors.onBrand,
              padding: const EdgeInsets.symmetric(vertical: SquishyTokens.space3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radiusSm)),
            ),
            onPressed: () => _share(context, target),
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1),
          ),
        );
    return Row(
      children: [
        brand('WhatsApp', Icons.chat_rounded, ShareColors.whatsapp, 'whatsapp'),
        const SizedBox(width: SquishyTokens.space2),
        brand('Gmail', Icons.mail_rounded, ShareColors.gmail, 'gmail'),
        const SizedBox(width: SquishyTokens.space1),
        if (showPlay)
          IconButton.filledTonal(
            tooltip: 'Play',
            onPressed: () => playVideo(context, path),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        IconButton.filledTonal(
          tooltip: 'Share with…',
          onPressed: () => _share(context, 'any'),
          icon: const Icon(Icons.share_rounded),
        ),
      ],
    );
  }
}
