import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openremote_android/core/models/device.dart';
import 'package:openremote_android/core/networking/api_client.dart';
import 'package:openremote_android/features/file_transfer/file_transfer_screen.dart';

void main() {
  Device buildDevice() {
    return const Device(
      id: 'desk',
      name: 'Desk PC',
      host: '192.168.0.10',
      port: 9876,
      serviceType: '_openremote._tcp',
      accessToken: 'secret',
    );
  }

  testWidgets('FileTransferScreen uploads pending shares',
      (WidgetTester tester) async {
    var called = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileTransferScreen(
            enabled: true,
            device: buildDevice(),
            apiClient: const ApiClient(),
            pendingSharedCount: 2,
            onUploadPendingShares: () async {
              called += 1;
            },
          ),
        ),
      ),
    );

    expect(find.text('Upload Pending Shares'), findsOneWidget);

    await tester.tap(find.text('Upload Pending Shares'));
    await tester.pump();

    expect(called, 1);
  });

  testWidgets('FileTransferScreen disables choose file when disabled',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FileTransferScreen(
            enabled: false,
            device: buildDevice(),
            apiClient: const ApiClient(),
            pendingSharedCount: 0,
            onUploadPendingShares: () async {},
          ),
        ),
      ),
    );

    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Choose File'));
    expect(button.onPressed, isNull);
  });
}
