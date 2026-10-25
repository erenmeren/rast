import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'export.dart';
import 'lab_store.dart';
import 'models.dart';
import 'providers.dart';

class SessionsPage extends ConsumerStatefulWidget {
  const SessionsPage({super.key});

  @override
  ConsumerState<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends ConsumerState<SessionsPage> {
  int _revision = 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(labStoreProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      body: store.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Store failed: $e')),
        data: (s) => FutureBuilder<List<LabSession>>(
          key: ValueKey(_revision),
          future: s.sessions(),
          builder: (context, snap) {
            final sessions = snap.data;
            if (sessions == null) return const Center(child: CircularProgressIndicator());
            if (sessions.isEmpty) return const Center(child: Text('No sessions yet'));
            return ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, i) => _SessionTile(
                store: s,
                session: sessions[i],
                onChanged: () => setState(() => _revision++),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.store, required this.session, required this.onChanged});

  final LabStore store;
  final LabSession session;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startedAtUtcMs, isUtc: true).toLocal();
    final end = session.endedAtUtcMs;
    final duration = end == null
        ? 'open'
        : '${((end - session.startedAtUtcMs) / 60000).round()} min';
    return FutureBuilder<int>(
      future: store.sampleCount(session.id),
      builder: (context, snap) => ListTile(
        title: Text('${start.toString().substring(0, 16)}  ·  ${session.requestedIntervalS} s'),
        subtitle: Text(
          '$duration · ${snap.data ?? '…'} samples · ${session.requestedAccuracy.name} · ${session.deviceModel}',
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'export') {
              final root = await ref.read(documentsDirProvider.future);
              final files = await writeExport(store, session, root);
              await shareExport(files, subject: 'rast lab ${session.deviceModel} ${session.id}');
            } else if (value == 'delete') {
              await store.deleteSession(session.id);
              onChanged();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'export', child: Text('Export')),
            // A running session is still being written to; stop it first.
            if (end != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
