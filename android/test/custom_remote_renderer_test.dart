import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/command.dart';
import 'package:openremote_android/core/models/remote_layout.dart';
import 'package:openremote_android/features/custom_remotes/remote_renderer.dart';

void main() {
  testWidgets('CustomRemoteScreen renders dpad and grid controls',
      (WidgetTester tester) async {
    final sent = <CommandEnvelope>[];
    final remote = RemoteLayout.fromJson(<String, dynamic>{
      'id': 'meeting-controls',
      'name': 'Meeting Controls',
      'category': 'productivity',
      'canvas': <String, dynamic>{
        'width': 1000,
        'height': 1600,
        'grid_size': 40,
      },
      'layout': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'slides',
          'type': 'dpad',
          'label': 'Slides',
          'frame': <String, dynamic>{
            'x': 60,
            'y': 60,
            'width': 420,
            'height': 420,
          },
          'props': <String, dynamic>{
            'left': <String, dynamic>{
              'label': 'Prev',
              'command': 'presentation_previous',
            },
            'right': <String, dynamic>{
              'label': 'Next',
              'command': 'presentation_next',
            },
            'center': <String, dynamic>{
              'label': 'Blank',
              'command': 'presentation_blackout',
            },
          },
        },
        <String, dynamic>{
          'id': 'quick-actions',
          'type': 'grid_buttons',
          'label': 'Quick Actions',
          'frame': <String, dynamic>{
            'x': 60,
            'y': 540,
            'width': 720,
            'height': 320,
          },
          'props': <String, dynamic>{
            'columns': 2,
            'buttons': <Map<String, dynamic>>[
              <String, dynamic>{
                'label': 'Stop',
                'command': 'media_stop',
              },
              <String, dynamic>{
                'label': 'Quiet Room',
                'command': 'volume_set',
                'props': <String, dynamic>{'value': 0},
              },
            ],
          },
        },
      ],
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomRemoteScreen(
            enabled: true,
            remotes: <RemoteLayout>[remote],
            favoriteRemoteIds: const <String>{},
            onSend: (CommandEnvelope command) async {
              sent.add(command);
            },
            onToggleFavoriteRemote: (RemoteLayout remote) async {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('remote-canvas-meeting-controls')),
        findsOneWidget);
    expect(find.text('Slides'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Prev'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Prev'));
    await tester.pump();
    await tester.tap(find.text('Quiet Room'));
    await tester.pump();

    expect(sent, hasLength(2));
    expect(sent[0].commandName, 'presentation_previous');
    expect(sent[0].remoteId, 'meeting-controls');
    expect(sent[1].commandName, 'volume_set');
    expect(sent[1].arguments['value'], 0);
  });
}
