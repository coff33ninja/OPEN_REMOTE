import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PairQrScannerScreen extends StatefulWidget {
  const PairQrScannerScreen({super.key});

  @override
  State<PairQrScannerScreen> createState() => _PairQrScannerScreenState();
}

class _PairQrScannerScreenState extends State<PairQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handlingScan = false;
  String _status = 'Align the OpenRemote QR code inside the frame.';

  Future<void> _handleCapture(BarcodeCapture capture) async {
    if (_handlingScan) {
      return;
    }

    final value = capture.barcodes.firstOrNull?.displayValue?.trim();
    if (value == null || value.isEmpty) {
      return;
    }
    if (!value.startsWith('openremote://pair')) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'That code is not an OpenRemote pair URI.';
      });
      return;
    }

    _handlingScan = true;
    await _controller.stop();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Pairing QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: <Widget>[
          MobileScanner(
            controller: _controller,
            onDetect: _handleCapture,
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFBBF24),
                    width: 3,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              color: const Color(0xAA000000),
              child: Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
