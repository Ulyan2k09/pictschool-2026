// Заглушка симуляции для локального запуска приложения.
//
// Backend на каждый ход отправляет команды движения в симуляцию по TCP на
// порт 5055. Если на этом порту никто не слушает — ход падает с ошибкой
// `simulation_error`, и играть нельзя. Эта заглушка просто ПРИНИМАЕТ команды,
// чтобы MVP работал сквозь (само движение считает backend).
//
// Запуск (из папки mobile/):
//   dart run tool/sim_stub.dart
//
// Настоящую симуляцию (движение платформы, телеметрию на порт 5056) делает
// трек computer-systems — здесь лишь минимальная «затычка» для порта команд.

import 'dart:io';

Future<void> main() async {
  const host = '127.0.0.1';
  const port = 5055;

  final server = await ServerSocket.bind(host, port);
  stdout.writeln('[sim] заглушка слушает $host:$port (порт команд).');
  stdout.writeln('[sim] backend будет присылать строки вида "1 1 3 4". Ctrl+C — стоп.');

  await for (final socket in server) {
    socket.listen(
      (data) {
        final text = String.fromCharCodes(data).trim();
        stdout.writeln('[sim] получены команды: "$text"');
        // TODO(school): превратить команды в движение платформы (трек computer-systems).
      },
      onError: (_) {},
      cancelOnError: false,
    );
  }
}
