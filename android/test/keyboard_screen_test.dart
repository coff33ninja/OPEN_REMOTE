import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/command.dart';
import 'package:openremote_android/features/keyboard_remote/keyboard_screen.dart';
import 'package:openremote_android/ui/widgets/remote_button.dart';

void main() {
  void setViewSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('KeyboardScreen sends text, keys, modifiers, and shortcuts',
      (WidgetTester tester) async {
    setViewSize(tester, const Size(1200, 2200));

    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField).first,
      'hello world',
    );
    await tester.tap(find.widgetWithText(RemoteButton, 'Send Text'));
    await tester.pump();

    expect(sent[0].commandName, 'keyboard_type');
    expect(sent[0].arguments['text'], 'hello world');

    await tester.tap(find.text('Ctrl'));
    await tester.pump();

    expect(sent[1].commandName, 'keyboard_key_down');
    expect(sent[1].arguments['key'], 'ctrl');

    await tester.scrollUntilVisible(
      find.text('Single Key'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).last,
      'F5',
    );
    await tester.tap(find.widgetWithText(RemoteButton, 'Send Key'));
    await tester.pump();

    expect(sent[2].commandName, 'keyboard_press');
    expect(sent[2].arguments['key'], 'F5');

    await tester.scrollUntilVisible(
      find.text('Alt+Tab'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alt+Tab'));
    await tester.pump();

    expect(sent[3].commandName, 'keyboard_shortcut');
    expect(sent[3].arguments['keys'], <String>['alt', 'tab']);

    await tester.scrollUntilVisible(
      find.text('Ctrl'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ctrl'));
    await tester.pump();

    expect(sent[4].commandName, 'keyboard_key_up');
    expect(sent[4].arguments['key'], 'ctrl');
  });

  testWidgets('KeyboardScreen releases held modifiers on dispose',
      (WidgetTester tester) async {
    setViewSize(tester, const Size(1200, 2200));

    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Shift'));
    await tester.pump();

    expect(sent, hasLength(1));
    expect(sent.first.commandName, 'keyboard_key_down');

    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();

    expect(sent.last.commandName, 'keyboard_key_up');
    expect(sent.last.arguments['key'], 'shift');
  });

  testWidgets('KeyboardScreen live IME mode syncs only committed text',
      (WidgetTester tester) async {
    setViewSize(tester, const Size(1200, 2200));

    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Live IME-aware sync'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.showKeyboard(find.byType(TextField).first);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'nihon',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ),
    );
    await tester.pump();

    expect(sent, isEmpty);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '日本',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange.empty,
      ),
    );
    await tester.pumpAndSettle();

    expect(sent, hasLength(1));
    expect(sent.first.commandName, 'keyboard_type');
    expect(sent.first.arguments['text'], '日本');
  });

  testWidgets('KeyboardScreen uses staged popout panels on compact screens',
      (WidgetTester tester) async {
    setViewSize(tester, const Size(430, 960));

    final sent = <CommandEnvelope>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KeyboardScreen(
            enabled: true,
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
          ),
        ),
      ),
    );

    expect(find.text('Quick Keys'), findsOneWidget);
    expect(find.text('Single Key'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('More Keys'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('More Keys'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Navigation'));
    await tester.pumpAndSettle();

    expect(find.text('Navigation Keys'), findsOneWidget);

    await tester.tap(find.text('Left'));
    await tester.pump();

    expect(sent, hasLength(1));
    expect(sent.first.commandName, 'keyboard_press');
    expect(sent.first.arguments['key'], 'left');

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Shortcuts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alt+Tab'));
    await tester.pump();

    expect(sent.last.commandName, 'keyboard_shortcut');
    expect(sent.last.arguments['keys'], <String>['alt', 'tab']);
  });
}
