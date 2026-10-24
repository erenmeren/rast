import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lab_store.dart';
import 'models.dart';
import 'permissions.dart';
import 'providers.dart';
import 'sampler.dart';

const intervalOptions = [15, 30, 60, 120];

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _intervalS = 30;
  RequestedAccuracy _accuracy = RequestedAccuracy.high;
  PermissionSnapshot? _permissions;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshPermissions();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final snap = await ref.read(permissionFlowProvider).snapshot();
    if (mounted) setState(() => _permissions = snap);
  }

  Future<void> _fixPermission(Sampler sampler) async {
    final item = await ref.read(permissionFlowProvider).requestNextMissing();
    if (item != null) await sampler.logEvent(EventKind.permission, 'requested ${item.name}');
    await _refreshPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final sampler = ref.watch(samplerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('rast location lab'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            tooltip: 'Sessions',
            onPressed: () => Navigator.of(context).pushNamed('/sessions'),
          ),
        ],
      ),
      body: sampler.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Store failed: $e')),
        data: (s) => ListenableBuilder(
          listenable: s,
          builder: (context, _) => _body(context, s),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, Sampler sampler) {
    final status = sampler.status;
    final store = ref.watch(labStoreProvider).value;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _permissionRow(sampler),
        const SizedBox(height: 16),
        Text('Interval', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final s in intervalOptions)
              ChoiceChip(
                label: Text('$s s'),
                selected: _intervalS == s,
                onSelected: status.running ? null : (_) => setState(() => _intervalS = s),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Accuracy', style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final a in RequestedAccuracy.values)
              ChoiceChip(
                label: Text(_accuracyLabel(a)),
                selected: _accuracy == a,
                onSelected: status.running ? null : (_) => setState(() => _accuracy = a),
              ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: status.busy
              ? null
              : () => status.running
                  ? sampler.stop()
                  : sampler.start(SamplerConfig(intervalS: _intervalS, accuracy: _accuracy)),
          child: Text(status.busy
              ? (status.running ? 'Stopping…' : 'Starting…')
              : (status.running ? 'Stop' : 'Start')),
        ),
        const SizedBox(height: 16),
        _LivePanel(sampler: sampler),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: status.running ? () => sampler.marker('together') : null,
                child: const Text('Together'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: status.running ? () => sampler.marker('apart') : null,
                child: const Text('Apart'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _note,
                decoration: const InputDecoration(hintText: 'Note'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: status.running
                  ? () {
                      final text = _note.text.trim();
                      if (text.isEmpty) return;
                      sampler.note(text);
                      _note.clear();
                    }
                  : null,
              child: const Text('Add note'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Events', style: Theme.of(context).textTheme.labelLarge),
        if (store != null && status.sessionId != null)
          _EventFeed(store: store, sessionId: status.sessionId!, revision: status.eventRevision),
      ],
    );
  }

  Widget _permissionRow(Sampler sampler) {
    final snap = _permissions;
    if (snap == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 12,
                children: [
                  for (final item in PermissionItem.values)
                    Chip(
                      avatar: Icon(
                        snap.granted[item] == true ? Icons.check_circle : Icons.cancel,
                        size: 18,
                      ),
                      label: Text(_permissionLabel(item)),
                    ),
                ],
              ),
            ),
            if (!snap.allGranted)
              FilledButton.tonal(
                onPressed: () => _fixPermission(sampler),
                child: const Text('Fix'),
              ),
          ],
        ),
      ),
    );
  }

}

String _accuracyLabel(RequestedAccuracy a) => switch (a) {
      RequestedAccuracy.best => 'Best',
      RequestedAccuracy.high => 'High',
      RequestedAccuracy.medium => 'Medium',
    };

String _permissionLabel(PermissionItem item) => switch (item) {
      PermissionItem.fineLocation => 'Precise',
      PermissionItem.backgroundLocation => 'Always',
      PermissionItem.notifications => 'Notifications',
    };

/// Live numbers. Ticks once a second so "Last fix" keeps ageing even when no
/// new fix arrives, which is exactly the situation the tester must notice.
class _LivePanel extends StatefulWidget {
  const _LivePanel({required this.sampler});

  final Sampler sampler;

  @override
  State<_LivePanel> createState() => _LivePanelState();
}

class _LivePanelState extends State<_LivePanel> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.sampler.status;
    final lastFix = status.lastFixUtcMs;
    final ageS = lastFix == null
        ? null
        : ((widget.sampler.now().millisecondsSinceEpoch - lastFix) / 1000).round();
    final acc = status.lastAccuracyM;
    final errorColor = Theme.of(context).colorScheme.error;
    final stale = ageS != null && status.running && ageS > 3 * _staleIntervalS(status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Samples: ${status.sampleCount}'),
            Text(
              'Last fix: ${ageS == null ? '–' : '$ageS s ago'}',
              style: stale ? TextStyle(color: errorColor, fontWeight: FontWeight.bold) : null,
            ),
            Text('Accuracy: ${acc == null ? '–' : '${acc.round()} m'}'),
            Text('State: ${status.lifecycle.name}'),
            Text('Battery: ${status.batteryPct == null ? '–' : '${status.batteryPct}%'}'),
            if (status.lastStreamError != null)
              Text('Stream error: ${status.lastStreamError}', style: TextStyle(color: errorColor)),
            if (status.lastWriteError != null)
              Text('Write error: ${status.lastWriteError}', style: TextStyle(color: errorColor)),
          ],
        ),
      ),
    );
  }

  /// The panel does not know the requested interval; 120 s is the longest
  /// option, so anything older than 6 minutes is stale for every setting.
  int _staleIntervalS(SamplerStatus status) => intervalOptions.last;
}

class _EventFeed extends StatelessWidget {
  const _EventFeed({required this.store, required this.sessionId, required this.revision});

  final LabStore store;
  final String sessionId;
  final int revision;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<LabEvent>>(
      key: ValueKey('$sessionId-$revision'),
      future: store.events(sessionId),
      builder: (context, snap) {
        final events = snap.data ?? const [];
        final recent = events.length > 20 ? events.sublist(events.length - 20) : events;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in recent.reversed)
              Text(
                '${_time(e.timeUtcMs)}  ${e.kind.wire}: ${e.detail}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        );
      },
    );
  }

  String _time(int ms) {
    final t = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
