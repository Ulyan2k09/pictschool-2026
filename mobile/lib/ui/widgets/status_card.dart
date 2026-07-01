import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';

/// Верхняя сводка раунда: счёт участников, чей ход, прогресс по уточкам.
class StatusCard extends StatelessWidget {
  final Round round;

  const StatusCard({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    final collected = round.ducksTotal - round.ducksLeft;
    final progress =
        round.ducksTotal == 0 ? 0.0 : collected / round.ducksTotal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _TeamTile(
                    label: 'Робот',
                    score: round.score.robot,
                    color: AppTheme.robot,
                    active: round.activeActor == 'robot' && round.isRunning,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TeamTile(
                    label: 'Агент',
                    score: round.score.agent,
                    color: AppTheme.agent,
                    active: round.activeActor == 'agent' && round.isRunning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoChip(icon: Icons.flag_outlined, label: 'Ход ${round.turnNumber}'),
                const SizedBox(width: 8),
                _StatusChip(status: round.status),
                const Spacer(),
                Text(
                  'Уточки: $collected / ${round.ducksTotal}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                color: AppTheme.duck,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  final bool active;

  const _TeamTile({
    required this.label,
    required this.score,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: active
            ? color.withValues(alpha: 0.14)
            : Theme.of(context).colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active ? color : Theme.of(context).colorScheme.outlineVariant,
          width: active ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(
              label[0],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(
                  '$score',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                ),
              ],
            ),
          ),
          if (active)
            Icon(Icons.play_arrow_rounded, color: color, size: 22),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'running' => ('Идёт', Colors.green),
      'completed' => ('Завершён', Colors.blue),
      'failed' => ('Сбой', Colors.red),
      _ => ('Ожидание', Colors.grey),
    };
    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
