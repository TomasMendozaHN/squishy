import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/theme.dart';
import '../../core/format.dart';
import '../../core/nas.dart';
import '../../widgets/common.dart';
import 'nas_browser_screen.dart';

/// Saved NAS shares with their all-time savings.
class NasScreen extends StatefulWidget {
  const NasScreen({super.key});

  @override
  State<NasScreen> createState() => _NasScreenState();
}

class _NasScreenState extends State<NasScreen> {
  List<NasServerInfo>? _servers;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await NasNative.servers();
    if (mounted) setState(() => _servers = list);
  }

  Future<void> _edit([NasServerInfo? server]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ServerForm(server: server),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(NasServerInfo s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${s.name}?'),
        content: const Text('Only removes it from this phone. Nothing on the NAS is touched.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok == true) {
      await NasNative.delete(s.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final servers = _servers;
    return Scaffold(
      appBar: AppBar(title: const Text('Network (NAS)')),
      floatingActionButton: servers == null || servers.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _edit,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add NAS'),
            ),
      body: servers == null
          ? const Center(child: CircularProgressIndicator())
          : servers.isEmpty
              ? EmptyState(
                  icon: Icon(Icons.lan_rounded, size: 72, color: context.tokens.liquidA),
                  title: 'Squish your media server',
                  message: 'Add a shared folder (SMB) from your NAS or PC. Squishy compresses every video '
                      'in place, keeping names, folders, audio tracks and subtitles, so Plex just sees smaller files.',
                  action: GradientButton(
                    label: 'Add NAS',
                    icon: Icons.add_rounded,
                    expand: false,
                    onPressed: _edit,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(SquishyTokens.space4, SquishyTokens.space4, SquishyTokens.space4, 96),
                  itemCount: servers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: SquishyTokens.space3),
                  itemBuilder: (context, i) => _ServerCard(
                    server: servers[i],
                    onOpen: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => NasBrowserScreen(server: servers[i])),
                    ),
                    onEdit: () => _edit(servers[i]),
                    onDelete: () => _delete(servers[i]),
                  ).animate().fadeIn(delay: (60 * i).ms).slideY(begin: 0.1, end: 0),
                ),
    );
  }
}

class _ServerCard extends StatelessWidget {
  const _ServerCard({required this.server, required this.onOpen, required this.onEdit, required this.onDelete});

  final NasServerInfo server;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GlassCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: t.liquidGradient, borderRadius: BorderRadius.circular(t.radiusSm)),
                child: Icon(Icons.dns_rounded, color: context.colors.surface),
              ),
              const SizedBox(width: SquishyTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(server.name, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(server.address, style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
          const SizedBox(height: SquishyTokens.space3),
          FutureBuilder<NasStats>(
            future: NasNative.stats(server.id),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text(
                  "Can't reach it right now",
                  style: context.text.bodySmall?.copyWith(color: t.warning),
                );
              }
              final s = snap.data;
              if (s == null) return const LinearProgressIndicator();
              return Wrap(
                spacing: SquishyTokens.space2,
                runSpacing: SquishyTokens.space1,
                children: [
                  Pill('${formatBytes(s.saved)} saved', icon: Icons.savings_rounded, color: t.success),
                  Pill('${s.files} squished', icon: Icons.movie_filter_rounded),
                  for (final e in s.folders.entries)
                    Pill('${e.key}: ${e.value.files}', icon: Icons.folder_rounded, color: t.liquidB),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServerForm extends StatefulWidget {
  const _ServerForm({this.server});

  final NasServerInfo? server;

  @override
  State<_ServerForm> createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  late final _name = TextEditingController(text: widget.server?.name);
  late final _host = TextEditingController(
    text: widget.server == null ? null : '${widget.server!.host}${widget.server!.port == 445 ? '' : ':${widget.server!.port}'}',
  );
  late final _share = TextEditingController(text: widget.server?.share);
  late final _user = TextEditingController(text: widget.server?.username);
  final _password = TextEditingController();
  late final _domain = TextEditingController(text: widget.server?.domain);
  bool _busy = false;
  String? _result;
  bool _ok = false;

  Map<String, Object?> get _fields => {
        'id': widget.server?.id,
        'name': _name.text,
        'host': _host.text,
        'share': _share.text,
        'username': _user.text,
        'password': _password.text,
        'domain': _domain.text,
      };

  bool get _valid => _host.text.trim().isNotEmpty && _share.text.trim().isNotEmpty;

  Future<void> _test() async {
    setState(() {
      _busy = true;
      _result = null;
    });
    try {
      await NasNative.test(_fields);
      setState(() {
        _ok = true;
        _result = 'Connected!';
      });
    } on PlatformException catch (e) {
      setState(() {
        _ok = false;
        _result = e.message ?? 'Could not connect';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    await NasNative.save(_fields);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    InputDecoration deco(String label, {String? hint, String? helper}) =>
        InputDecoration(labelText: label, hintText: hint, helperText: helper);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        SquishyTokens.space4,
        0,
        SquishyTokens.space4,
        SquishyTokens.space4 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.server == null ? 'Add NAS' : 'Edit NAS', style: context.text.headlineSmall),
            const SizedBox(height: SquishyTokens.space4),
            TextField(controller: _name, decoration: deco('Name', hint: 'Plex server')),
            const SizedBox(height: SquishyTokens.space3),
            TextField(
              controller: _host,
              keyboardType: TextInputType.url,
              decoration: deco('Address', hint: '192.168.1.20', helper: 'IP or name. Add :port if it isn\'t 445'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SquishyTokens.space3),
            TextField(
              controller: _share,
              decoration: deco('Shared folder', hint: 'media', helper: 'The share name, e.g. \\\\192.168.1.20\\media → media'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: SquishyTokens.space3),
            TextField(controller: _user, decoration: deco('Username', helper: 'Leave empty for guest access')),
            const SizedBox(height: SquishyTokens.space3),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: deco(
                'Password',
                helper: widget.server?.hasPassword == true ? 'Leave empty to keep the saved password' : 'Stored encrypted on this phone',
              ),
            ),
            const SizedBox(height: SquishyTokens.space3),
            TextField(controller: _domain, decoration: deco('Domain / workgroup (optional)')),
            const SizedBox(height: SquishyTokens.space4),
            if (_result != null)
              Padding(
                padding: const EdgeInsets.only(bottom: SquishyTokens.space3),
                child: Row(
                  children: [
                    Icon(_ok ? Icons.check_circle_rounded : Icons.error_rounded, color: _ok ? t.success : t.danger),
                    const SizedBox(width: SquishyTokens.space2),
                    Expanded(child: Text(_result!, style: context.text.bodyMedium)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy || !_valid ? null : _test,
                    icon: _busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.network_check_rounded),
                    label: const Text('Test'),
                  ),
                ),
                const SizedBox(width: SquishyTokens.space3),
                Expanded(
                  child: GradientButton(
                    label: 'Save',
                    icon: Icons.check_rounded,
                    onPressed: _busy || !_valid ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
