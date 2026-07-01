import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models.dart';
import '../state/game_controller.dart';
import 'widgets/board_view.dart';
import 'widgets/command_panel.dart';
import 'widgets/event_feed.dart';
import 'widgets/status_card.dart';

/// Главный (и единственный в MVP) экран приложения.
///
/// Собирает виджеты в один экран и подписывается на [GameController].
/// Добавить второй экран (например, настройки адреса сервера) — хорошая
/// задача для участников.
class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<GameController>();
    return Scaffold(
      appBar: AppBar(
        // TODO(school): заголовок и брендинг приложения (задача 2).
        title: const Text('Duck Round'),
        centerTitle: false,
        actions: [
          _OnlineDot(online: controller.online),
          IconButton(
            onPressed: controller.busy ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _Body(controller: controller),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final GameController controller;

  const _Body({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final round = controller.round;
    if (round == null) {
      return _ErrorState(
        message: controller.error?.message ??
            'Не удалось получить состояние игры.',
        onRetry: controller.refresh,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (controller.error != null)
            _ErrorBanner(
              error: controller.error!,
              onClose: controller.clearError,
            ),
          if (!controller.online) const _OfflineBanner(),
          StatusCard(round: round),
          const SizedBox(height: 12),
          _Controls(controller: controller, round: round),
          const SizedBox(height: 12),
          _BoardCard(round: round),
          const SizedBox(height: 12),
          if (round.isCompleted) _WinnerBanner(round: round),
          const CommandPanel(),
          const SizedBox(height: 12),
          EventFeed(events: controller.events),
        ],
      ),
    );
  }
}

class _BoardCard extends StatelessWidget {
  final Round round;

  const _BoardCard({required this.round});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: AspectRatio(
          aspectRatio: round.field.width / round.field.height,
          child: BoardView(round: round),
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final GameController controller;
  final Round round;

  const _Controls({required this.controller, required this.round});

  @override
  Widget build(BuildContext context) {
    final canStart = !round.isRunning && !controller.busy;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: canStart ? controller.startRound : null,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Старт раунда'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.busy ? null : controller.resetRound,
            icon: const Icon(Icons.restart_alt_rounded),
            label: const Text('Сброс'),
          ),
        ),
      ],
    );
  }
}

class _WinnerBanner extends StatelessWidget {
  final Round round;

  const _WinnerBanner({required this.round});

  @override
  Widget build(BuildContext context) {
    final s = round.score;
    final winner = s.robot > s.agent
        ? 'Победил Робот'
        : s.agent > s.robot
            ? 'Победил Агент'
            : 'Ничья';
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Text('🏁', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Раунд завершён',
                    style: Theme.of(context).textTheme.labelMedium),
                Text(
                  '$winner  ·  ${s.robot} : ${s.agent}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final dynamic error; // ApiException
  final VoidCallback onClose;

  const _ErrorBanner({required this.error, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${error.code}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  '${error.message}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: scheme.onErrorContainer),
            tooltip: 'Скрыть',
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Нет связи с сервером. Проверьте, что backend запущен '
              '(${_hint(context)}).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  String _hint(BuildContext context) => 'см. mobile/README.md';
}

class _OnlineDot extends StatelessWidget {
  final bool online;

  const _OnlineDot({required this.online});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Tooltip(
        message: online ? 'Связь с сервером есть' : 'Нет связи',
        child: Icon(
          online ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          size: 20,
          color: online ? Colors.green : Colors.orange,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56),
            const SizedBox(height: 16),
            Text(
              'Нет связи с backend',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Запустите backend и заглушку симуляции (см. README), '
              'затем повторите.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}
