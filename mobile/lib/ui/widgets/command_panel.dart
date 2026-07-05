import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../state/game_controller.dart';

/// Одна команда движения: код, иконка и подпись.
class _Command {
  final int code;
  final IconData icon;
  final String label;
  const _Command(this.code, this.icon, this.label);
}

const List<_Command> _commands = [
  _Command(1, Icons.arrow_upward_rounded, 'Вперёд'),
  _Command(2, Icons.arrow_downward_rounded, 'Назад'),
  _Command(3, Icons.rotate_left_rounded, 'Влево'),
  _Command(4, Icons.rotate_right_rounded, 'Вправо'),
];

IconData iconForCode(int code) =>
    _commands.firstWhere((c) => c.code == code).icon;

/// Панель управления ходом: собрать до 5 команд и отправить их на backend.
///
/// Панель не двигает робота сама — она лишь собирает коды команд и отдаёт их
/// контроллеру, который отправляет их на backend.
class CommandPanel extends StatelessWidget {
  const CommandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    final round = controller.round;
    final running = round?.isRunning ?? false;
    final activeActor = controller.activeActor;
    final activeColor =
        activeActor == null ? null : AppTheme.actorColor(activeActor);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Ход', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (running && activeActor != null)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: activeColor,
                      radius: 10,
                    ),
                    label: Text(activeActor == 'robot' ? 'Робот' : 'Агент'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _QueueView(
              queue: controller.queue,
              limit: controller.moveLimit,
              onBackspace:
                  controller.queue.isEmpty ? null : controller.removeLastCommand,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.92,
              children: [
                for (final cmd in _commands)
                  _CommandButton(
                    icon: cmd.icon,
                    label: cmd.label,
                    color: activeColor ?? Theme.of(context).colorScheme.primary,
                    enabled: controller.canAddCommand,
                    onTap: () => controller.addCommand(cmd.code),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                TextButton.icon(
                  onPressed: controller.queue.isEmpty || controller.busy
                      ? null
                      : controller.clearQueue,
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Очистить'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: controller.canSubmit ? controller.submitTurn : null,
                  icon: controller.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text('Отправить ход (${controller.queue.length})'),
                ),
              ],
            ),
            if (!running)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  round == null || round.isIdle
                      ? 'Нажмите «Старт», чтобы начать раунд.'
                      : 'Раунд завершён. Нажмите «Сброс» для нового.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QueueView extends StatelessWidget {
  final List<int> queue;
  final int limit;
  final VoidCallback? onBackspace;

  const _QueueView({
    required this.queue,
    required this.limit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: queue.isEmpty
                ? Text(
                    'Соберите до $limit команд…',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < queue.length; i++)
                        _QueueChip(index: i + 1, code: queue[i]),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Text('${queue.length}/$limit',
              style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            onPressed: onBackspace,
            icon: const Icon(Icons.backspace_outlined),
            tooltip: 'Убрать последнюю',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _QueueChip extends StatelessWidget {
  final int index;
  final int code;

  const _QueueChip({required this.index, required this.code});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Icon(iconForCode(code), size: 20, color: scheme.onPrimaryContainer),
    );
  }
}

class _CommandButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _CommandButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = enabled
        ? color.withValues(alpha: 0.12)
        : scheme.surfaceContainerHighest.withValues(alpha: 0.3);
    final fg = enabled ? color : scheme.onSurface.withValues(alpha: 0.35);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: fg),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
