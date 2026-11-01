import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../core/native.dart';
import '../../widgets/common.dart';
import '../browser/video_tile.dart';

/// In-app folder chooser for the output location. Pops with the chosen path.
class FolderPickerScreen extends StatefulWidget {
  const FolderPickerScreen({super.key});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  String? _root;
  String? _dir;
  List<String> _folders = const [];

  @override
  void initState() {
    super.initState();
    SquishyNative.storageRoots().then((roots) {
      _root = roots.isEmpty ? '/storage/emulated/0' : roots.first.path;
      _open(_root!);
    });
  }

  Future<void> _open(String path) async {
    final dirs = <String>[];
    try {
      await for (final e in Directory(path).list(followLinks: false)) {
        if (e is Directory && !e.path.split('/').last.startsWith('.')) dirs.add(e.path);
      }
    } on FileSystemException {
      // Unreadable folders simply show as empty.
    }
    dirs.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    setState(() {
      _dir = path;
      _folders = dirs;
    });
  }

  Future<void> _newFolder() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(hintText: 'Folder name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    if (name == null || name.isEmpty || _dir == null) return;
    final created = '$_dir/$name';
    await Directory(created).create(recursive: true);
    _open(created);
  }

  @override
  Widget build(BuildContext context) {
    final atRoot = _dir == _root;
    return PopScope(
      canPop: atRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _dir != null) _open(_dir!.substring(0, _dir!.lastIndexOf('/')));
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_dir == null ? 'Choose folder' : (atRoot ? 'Internal storage' : _dir!.split('/').last)),
          actions: [
            IconButton(tooltip: 'New folder', icon: const Icon(Icons.create_new_folder_rounded), onPressed: _newFolder),
          ],
        ),
        body: _dir == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space2, SquishyTokens.space4, 120),
                itemCount: _folders.length,
                separatorBuilder: (_, _) => const SizedBox(height: SquishyTokens.space2),
                itemBuilder: (context, i) => FolderTile(path: _folders[i], onTap: () => _open(_folders[i]))
                    .animate()
                    .fadeIn(delay: (15 * i.clamp(0, 15)).ms),
              ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(SquishyTokens.space4),
            child: GradientButton(
              label: 'Save here',
              icon: Icons.check_rounded,
              onPressed: _dir == null ? null : () => Navigator.pop(context, _dir),
            ),
          ),
        ),
      ),
    );
  }
}
