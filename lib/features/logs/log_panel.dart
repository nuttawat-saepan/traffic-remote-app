import 'package:flutter/material.dart';

import '../serial/serial_models.dart';
import 'log_model.dart';

class LogPanel extends StatelessWidget {
  const LogPanel({super.key, required this.logs, required this.onClear});

  final List<TrafficLogEntry> logs;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${logs.length} log${logs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: logs.isEmpty ? null : onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear Logs'),
              ),
            ],
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? const Center(child: Text('No logs yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: logs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _LogCard(entry: logs[index]),
                ),
        ),
      ],
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final TrafficLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.status) {
      CommandResultStatus.success => const Color(0xFF00810E),
      CommandResultStatus.timeout => const Color(0xFF965E00),
      CommandResultStatus.unexpected => const Color(0xFF8A5A00),
      CommandResultStatus.error => const Color(0xFFB3261E),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    entry.action,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  entry.status.label.toUpperCase(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(_formatTimestamp(entry.timestamp)),
            const SizedBox(height: 8),
            SelectableText('Sent: ${entry.sentCommand}'),
            SelectableText(
              'Text: ${entry.receivedText.isEmpty ? '-' : entry.receivedText}',
            ),
            SelectableText(
              'Raw HEX: ${entry.receivedRawHex.isEmpty ? '-' : entry.receivedRawHex}',
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimestamp(DateTime timestamp) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(timestamp.hour)}:${two(timestamp.minute)}:${two(timestamp.second)} '
        '${two(timestamp.day)}/${two(timestamp.month)}/${timestamp.year}';
  }
}
