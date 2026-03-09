import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/remote_layout.dart';
import 'package:openremote_android/features/remote_designer/remote_designer_screen.dart';

void main() {
  testWidgets('RemoteDesignerScreen lists designed remotes',
      (WidgetTester tester) async {
    final remote = RemoteLayout.fromJson(<String, dynamic>{
      'id': 'custom-meeting',
      'name': 'Custom Meeting',
      'category': 'custom',
      'layout': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'play',
          'type': 'button',
          'label': 'Play',
          'command': 'media_toggle',
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteDesignerScreen(
            designedRemotes: <RemoteLayout>[remote],
            onSaveRemote: (RemoteLayout remote) async {},
            onDeleteRemote: (RemoteLayout remote) async {},
          ),
        ),
      ),
    );

    expect(find.text('Remote Designer'), findsOneWidget);
    expect(find.text('Custom Meeting'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Copy JSON'), findsOneWidget);
  });

  testWidgets('RemoteDesignerEditorScreen supports canvas editing',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const RemoteDesignerEditorScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.byKey(const Key('designer-canvas-surface')), findsOneWidget);
    expect(find.byKey(const Key('palette-button')), findsOneWidget);

    final paletteButton = find.byKey(const Key('palette-button'));
    final emptyCanvas = find.byKey(const Key('designer-canvas-surface'));
    final start = tester.getCenter(paletteButton);
    final end = tester.getCenter(emptyCanvas);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canvas-node-0')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('selected-control-label-field')),
      'Scene Toggle',
    );
    await tester.pumpAndSettle();

    expect(find.text('Scene Toggle'), findsWidgets);
  });
}
