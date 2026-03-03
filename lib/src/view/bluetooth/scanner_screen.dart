import 'package:ble_backend/ble_central.dart';
import 'package:ble_backend/ble_peripheral.dart';
import 'package:ble_backend/ble_scanner.dart';
import 'package:ble_backend/utils/timer_wrapper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/bluetooth/bluetooth_service.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/view/bluetooth/jumping_dots.dart';
import 'package:lichess_mobile/src/view/bluetooth/ui_consts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({required this.bleCentral, required this.bleScanner, super.key});

  final BleCentral bleCentral;
  final BleScanner bleScanner;

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final scanTimer = TimerWrapper();

  BleCentral get bleCentral => widget.bleCentral;
  BleScanner get bleScanner => widget.bleScanner;

  void _evaluateBleCentralStatus(BleCentralStatus status) {
    setState(() {
      if (status != BleCentralStatus.unknown) {
        _stopScan();
      }
    });
  }

  void _startScan() {
    WakelockPlus.enable();
    bleScanner.scan();

    scanTimer.start(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    scanTimer.stop();
    WakelockPlus.disable();
    bleScanner.stop();
  }

  Widget _buildDeviceCard(BlePeripheral device) => Card(
    child: ListTile(
      shape: const RoundedRectangleBorder(borderRadius: Styles.cardBorderRadius),
      title: Text(device.name ?? ''),
      subtitle: Text("${device.id}\nRSSI: ${device.rssi ?? ''}"),
      leading: const Icon(Icons.bluetooth_rounded),
      onTap: () async {
        _stopScan();
        final service = ref.read(bluetoothServiceProvider);
        await service.connect(device.createConnector());
      },
    ),
  );

  Widget _buildDevicesList() {
    final devices = bleScanner.state.devices;
    final additionalElement = bleScanner.state.isScanInProgress ? 1 : 0;

    return ListView.builder(
      itemCount: devices.length + additionalElement,
      itemBuilder: (context, index) => index != devices.length
          ? _buildDeviceCard(devices[index])
          : Padding(padding: const EdgeInsets.all(25.0), child: createJumpingDots()),
    );
  }

  Widget _buildScanButton() => FilledButton.icon(
    icon: const Icon(Icons.search_rounded),
    label: const Text('Scan'),
    onPressed: !bleScanner.state.isScanInProgress ? _startScan : null,
  );

  Widget _buildStopButton() => FilledButton.icon(
    icon: const Icon(Icons.search_off_rounded),
    label: const Text('Stop'),
    onPressed: bleScanner.state.isScanInProgress ? _stopScan : null,
  );

  Widget _buildControlButtons() => SizedBox(
    height: kBluetoothButtonHeight,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildScanButton()),
        if (!kIsWeb) const SizedBox(width: kBluetoothSplitterWidth),
        if (!kIsWeb) Expanded(child: _buildStopButton()),
      ],
    ),
  );

  Widget _buildPortrait() => Column(
    children: [
      Expanded(child: _buildDevicesList()),
      Padding(padding: Styles.sectionTopPadding, child: _buildControlButtons()),
    ],
  );

  Widget _buildLandscape() => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(child: _buildDevicesList()),
      Expanded(
        child: Padding(padding: Styles.sectionLeftPadding, child: _buildControlButtons()),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    bleCentral.stateStream.listen(_evaluateBleCentralStatus);
    _evaluateBleCentralStatus(bleCentral.state);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BleScannerState>(
      stream: bleScanner.stateStream,
      builder: (context, snapshot) => OrientationBuilder(
        builder: (context, orientation) =>
            orientation == Orientation.portrait ? _buildPortrait() : _buildLandscape(),
      ),
    );
  }
}
