import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/command.dart';
import 'package:openremote_android/features/mouse_remote/mouse_screen.dart';

void main() {
  testWidgets('MouseScreen sends click and drag lock commands',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MouseScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Touchpad'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(sent, hasLength(1));
    expect(sent.first.commandName, 'mouse_click');
    expect(sent.first.arguments['button'], 'left');

    await tester.tap(find.text('Double Click'));
    await tester.pump();

    expect(sent.last.commandName, 'mouse_double_click');

    await tester.tap(find.text('Drag Lock'));
    await tester.pump();

    expect(sent.last.commandName, 'mouse_button_down');

    await tester.tap(find.text('Release Drag'));
    await tester.pump();

    expect(sent.last.commandName, 'mouse_button_up');
  });

  testWidgets('MouseScreen scroll rail sends wheel commands',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MouseScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.drag(find.text('Scroll'), const Offset(0, 80));
    await tester.pump();

    expect(
      sent.where(
          (CommandEnvelope command) => command.commandName == 'mouse_scroll'),
      isNotEmpty,
    );
  });
}
