import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/networking/websocket_client.dart';
import 'package:openremote_android/ui/widgets/connection_status_pill.dart';

void main() {
  testWidgets('ConnectionStatusPill reflects connection state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionStatusPill(
            state: RemoteConnectionState.connecting,
          ),
        ),
      ),
    );

    expect(find.text('Connecting'), findsOneWidget);
    expect(find.byIcon(Icons.sync), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionStatusPill(
            state: RemoteConnectionState.connected,
          ),
        ),
      ),
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.byIcon(Icons.wifi), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ConnectionStatusPill(
            state: RemoteConnectionState.error,
          ),
        ),
      ),
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off), findsOneWidget);
  });
}
