import 'package:flutter/material.dart';

import '../../data/models.dart';

/// Лента последних событий раунда (журнал от backend).
///
/// Здесь только форматирование готовых данных — приложение не додумывает,
/// что произошло, а показывает то, что прислал backend.
class EventFeed extends StatelessWidget {
  final List<GameEvent> events;
  final int maxItems;

  const EventFeed({super.key, required this.events, this.maxItems = 12});

  @override
  Widget build(BuildContext context) {
    // Новейшие сверху.
    final recent = events.reversed.take(maxItems).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('События',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${events.length}',
                    style: Theme.of(context).textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (recent.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Пока событий нет.',
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              for (final event in recent) _EventRow(event: event),
          ],
        ),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  final GameEvent event;

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    final meta = _metaFor(event.type);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(meta.icon, size: 18, color: meta.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _describe(event),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text('#${event.turnNumber}',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _EventMeta {
  final IconData icon;
  final Color color;
  const _EventMeta(this.icon, this.color);
}

_EventMeta _metaFor(String type) => switch (type) {
      'round.started' => const _EventMeta(Icons.flag_rounded, Colors.green),
      'turn.submitted' => const _EventMeta(Icons.send_rounded, Colors.blue),
      'simulation.command_sent' =>
        const _EventMeta(Icons.cable_rounded, Colors.teal),
      'actor.moved' =>
        const _EventMeta(Icons.directions_run_rounded, Colors.indigo),
      'duck.collected' =>
        const _EventMeta(Icons.check_circle_rounded, Color(0xFFF9A825)),
      'turn.completed' =>
        const _EventMeta(Icons.done_all_rounded, Colors.blueGrey),
      'turn.failed' => const _EventMeta(Icons.error_rounded, Colors.red),
      'round.completed' =>
        const _EventMeta(Icons.emoji_events_rounded, Colors.amber),
      'round.reset' => const _EventMeta(Icons.refresh_rounded, Colors.grey),
      _ => const _EventMeta(Icons.circle_outlined, Colors.grey),
    };

String _actorName(String? actor) => switch (actor) {
      'robot' => 'Робот',
      'agent' => 'Агент',
      _ => '—',
    };

String _describe(GameEvent e) {
  final p = e.payload;
  switch (e.type) {
    case 'round.started':
      return 'Раунд начался';
    case 'turn.submitted':
      return '${_actorName(e.actor)}: команды ${p['commands'] ?? ''}';
    case 'simulation.command_sent':
      return 'В симуляцию: «${p['tcpPayload'] ?? ''}»';
    case 'actor.moved':
      final pos = p['finalPosition'];
      final dir = p['finalDirection'] ?? '';
      final where = pos is Map ? '(${pos['x']}, ${pos['y']})' : '';
      return '${_actorName(e.actor)} → $where, $dir';
    case 'duck.collected':
      return '${_actorName(e.actor)} собрал уточку ${p['duckId'] ?? ''}';
    case 'turn.completed':
      return 'Ход завершён → ${_actorName(p['nextActor'] as String?)}';
    case 'turn.failed':
      return 'Ход не прошёл: ${p['error'] ?? ''}';
    case 'round.completed':
      return 'Раунд завершён 🏁';
    case 'round.reset':
      return 'Сброс раунда';
    default:
      return e.type;
  }
}
