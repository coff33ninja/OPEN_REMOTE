import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/command.dart';
import 'package:openremote_android/features/media_remote/media_screen.dart';

void main() {
  testWidgets('MediaScreen sends media actions and volume set',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play / Pause'));
    await tester.tap(find.text('Next'));
    await tester.tap(find.text('Previous'));
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(
      sent.map((CommandEnvelope cmd) => cmd.commandName).toList(),
      containsAll(<String>[
        'media_toggle',
        'media_next',
        'media_previous',
        'media_stop',
      ]),
    );

    await tester.drag(find.byType(Slider), const Offset(200, 0));
    await tester.pumpAndSettle();

    final volumeCommand =
        sent.lastWhere((CommandEnvelope cmd) => cmd.type == 'volume');
    expect(volumeCommand.action, 'set');
    expect(volumeCommand.arguments['value'], isA<int>());
  });
}
