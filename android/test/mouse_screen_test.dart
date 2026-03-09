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

  testWidgets('MouseScreen maps two-finger tap to right click',
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

    final target = tester.getCenter(find.text('Touchpad'));
    final firstFinger = await tester.createGesture();
    final secondFinger = await tester.createGesture(pointer: 2);

    await firstFinger.down(target.translate(-14, 0));
    await secondFinger.down(target.translate(14, 0));
    await tester.pump(const Duration(milliseconds: 40));
    await firstFinger.up();
    await secondFinger.up();
    await tester.pump(const Duration(milliseconds: 250));

    expect(sent, hasLength(1));
    expect(sent.first.commandName, 'mouse_click');
    expect(sent.first.arguments['button'], 'right');
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
