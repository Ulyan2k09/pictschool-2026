import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/models.dart';

/// Игровое поле: сетка, препятствия, уточки и участники.
///
/// Полностью «рисующий» виджет: он ничего не считает, только показывает
/// состояние [round], полученное от backend.
class BoardView extends StatelessWidget {
  final Round round;

  const BoardView({super.key, required this.round});

  @override
  Widget build(BuildContext context) {
    final field = round.field;
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Держим клетки квадратными: подбираем размер под доступное место.
        final maxW = constraints.maxWidth;
        final maxH = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : maxW * field.height / field.width;
        final cell = (maxW / field.width) <= (maxH / field.height)
            ? maxW / field.width
            : maxH / field.height;
        final boardW = cell * field.width;
        final boardH = cell * field.height;
        return Center(
          child: SizedBox(
            width: boardW,
            height: boardH,
            child: CustomPaint(
              painter: _BoardPainter(
                round: round,
                scheme: scheme,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BoardPainter extends CustomPainter {
  final Round round;
  final ColorScheme scheme;

  _BoardPainter({required this.round, required this.scheme});

  @override
  void paint(Canvas canvas, Size size) {
    final field = round.field;
    final cell = size.width / field.width;

    _paintBackground(canvas, size);
    _paintGrid(canvas, size, cell, field);
    for (final obstacle in field.obstacles) {
      _paintObstacle(canvas, obstacle.position, cell);
    }
    for (final duck in field.ducks) {
      if (!duck.isCollected) _paintDuck(canvas, duck.position, cell);
    }
    // TODO(school): анимировать плавное перемещение между клетками (задача 7).
    round.actors.forEach((id, actor) {
      _paintActor(canvas, actor, cell, active: id == round.activeActor);
    });
  }

  void _paintBackground(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(16));
    canvas.drawRRect(
      rrect,
      Paint()..color = scheme.surfaceContainerHighest.withValues(alpha: 0.5),
    );
  }

  void _paintGrid(Canvas canvas, Size size, double cell, GameField field) {
    final line = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var x = 0; x <= field.width; x++) {
      canvas.drawLine(Offset(x * cell, 0), Offset(x * cell, size.height), line);
    }
    for (var y = 0; y <= field.height; y++) {
      canvas.drawLine(Offset(0, y * cell), Offset(size.width, y * cell), line);
    }
  }

  Rect _cellRect(Position p, double cell, {double inset = 0}) => Rect.fromLTWH(
        p.x * cell + inset,
        p.y * cell + inset,
        cell - inset * 2,
        cell - inset * 2,
      );

  void _paintObstacle(Canvas canvas, Position p, double cell) {
    final rrect = RRect.fromRectAndRadius(
      _cellRect(p, cell, inset: cell * 0.12),
      Radius.circular(cell * 0.16),
    );
    canvas.drawRRect(rrect, Paint()..color = AppTheme.obstacle);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _paintDuck(Canvas canvas, Position p, double cell) {
    final c = _cellRect(p, cell).center;
    final r = cell * 0.26;
    // тело
    canvas.drawCircle(c, r, Paint()..color = AppTheme.duck);
    // голова
    final head = Offset(c.dx + r * 0.7, c.dy - r * 0.7);
    canvas.drawCircle(head, r * 0.55, Paint()..color = AppTheme.duck);
    // глаз
    canvas.drawCircle(
      Offset(head.dx + r * 0.15, head.dy - r * 0.1),
      r * 0.12,
      Paint()..color = Colors.black87,
    );
    // клюв
    final beak = Path()
      ..moveTo(head.dx + r * 0.5, head.dy)
      ..lineTo(head.dx + r * 1.05, head.dy - r * 0.12)
      ..lineTo(head.dx + r * 1.05, head.dy + r * 0.18)
      ..close();
    canvas.drawPath(beak, Paint()..color = const Color(0xFFF57F17));
  }

  void _paintActor(Canvas canvas, ActorState actor, double cell,
      {required bool active}) {
    final rect = _cellRect(actor.position, cell, inset: cell * 0.14);
    final color = AppTheme.actorColor(actor.id);
    final rrect =
        RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.22));

    if (active) {
      // мягкое свечение под активным участником
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _cellRect(actor.position, cell, inset: cell * 0.06),
          Radius.circular(cell * 0.26),
        ),
        Paint()..color = color.withValues(alpha: 0.25),
      );
    }

    canvas.drawRRect(rrect, Paint()..color = color);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 1.5,
    );

    _paintDirectionArrow(canvas, rect, actor.direction);
    _paintLabel(canvas, rect.center, actor.id == 'robot' ? 'R' : 'A', cell);
  }

  void _paintDirectionArrow(Canvas canvas, Rect rect, String direction) {
    final center = rect.center;
    final reach = rect.width * 0.42;
    final wing = rect.width * 0.14;
    late Offset tip, a, b;
    switch (direction) {
      case 'N':
        tip = Offset(center.dx, center.dy - reach);
        a = Offset(center.dx - wing, center.dy - reach + wing);
        b = Offset(center.dx + wing, center.dy - reach + wing);
        break;
      case 'S':
        tip = Offset(center.dx, center.dy + reach);
        a = Offset(center.dx - wing, center.dy + reach - wing);
        b = Offset(center.dx + wing, center.dy + reach - wing);
        break;
      case 'E':
        tip = Offset(center.dx + reach, center.dy);
        a = Offset(center.dx + reach - wing, center.dy - wing);
        b = Offset(center.dx + reach - wing, center.dy + wing);
        break;
      case 'W':
      default:
        tip = Offset(center.dx - reach, center.dy);
        a = Offset(center.dx - reach + wing, center.dy - wing);
        b = Offset(center.dx - reach + wing, center.dy + wing);
        break;
    }
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(a.dx, a.dy)
      ..lineTo(b.dx, b.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
  }

  void _paintLabel(Canvas canvas, Offset center, String text, double cell) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: cell * 0.34,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) =>
      old.round != round || old.scheme != scheme;
}
