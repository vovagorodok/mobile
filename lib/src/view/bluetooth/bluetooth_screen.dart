import 'dart:async';

import 'package:ble_backend/ble_central.dart';
import 'package:ble_backend/ble_scanner.dart';
import 'package:ble_chess_peripheral_driver/ble_chess_peripheral_driver.dart';
import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/analysis/analysis_controller.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/bluetooth/bluetooth_service.dart';
import 'package:lichess_mobile/src/model/board_editor/board_editor_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/utils/navigation.dart';
import 'package:lichess_mobile/src/utils/screen.dart';
import 'package:lichess_mobile/src/utils/share.dart';
import 'package:lichess_mobile/src/view/analysis/analysis_screen.dart';
import 'package:lichess_mobile/src/view/bluetooth/options_screen.dart';
import 'package:lichess_mobile/src/view/bluetooth/scanner_screen.dart';
import 'package:lichess_mobile/src/view/bluetooth/status_screen.dart';
import 'package:lichess_mobile/src/view/bluetooth/ui_consts.dart';
import 'package:lichess_mobile/src/view/board_editor/board_editor_filters.dart';
import 'package:lichess_mobile/src/view/play/create_challenge_bottom_sheet.dart';
import 'package:lichess_mobile/src/view/user/search_screen.dart';
import 'package:lichess_mobile/src/widgets/adaptive_action_sheet.dart';
import 'package:lichess_mobile/src/widgets/bottom_bar.dart';
import 'package:lichess_mobile/src/widgets/buttons.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:lichess_mobile/src/widgets/platform.dart';
import 'package:share_plus/share_plus.dart';

class BluetoothScreen extends ConsumerStatefulWidget {
  const BluetoothScreen({required this.bleCentral, super.key});

  static Route<dynamic> buildRoute(BuildContext context, BleCentral bleCentral) {
    return buildScreenRoute(context, screen: BluetoothScreen(bleCentral: bleCentral));
  }

  final BleCentral bleCentral;

  @override
  ConsumerState<BluetoothScreen> createState() => _BluetoothScreenState();
}

class _BluetoothScreenState extends ConsumerState<BluetoothScreen> {
  BleCentral get bleCentral => widget.bleCentral;

  @override
  Widget build(BuildContext context) {
    final service = ref.read(bluetoothServiceProvider);
    return StreamBuilder<void>(
      stream: service.connectedStream,
      builder: (context, constraints) => Scaffold(
        appBar: AppBar(
          title: const Text('Bluetooth'), // TODO: TRANSLATE: context.l10n.bluetooth
          actions: [
            if (service.isConnected)
              IconButton(
                icon: const Icon(Icons.bluetooth_disabled_rounded),
                onPressed: service.disconnect,
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: Styles.bodyPadding,
            child: Center(
              child: LayoutBuilder(
                builder: (context, constraints) => StreamBuilder<BleCentralStatus>(
                  stream: bleCentral.stateStream,
                  builder: (context, constraints) => StreamBuilder<void>(
                    stream: service.initializedStream,
                    builder: (context, constraints) {
                      if (service.isInitialized && service.peripheral.isFeatureSupported.option) {
                        return OptionsScreen(peripheral: service.peripheral);
                      } else if (service.isConnected) {
                        return const SizedBox.shrink();
                      } else if (bleCentral.state == BleCentralStatus.ready) {
                        return ScannerScreen(
                          bleCentral: bleCentral,
                          bleScanner: bleCentral.createScanner(serviceIds: [serviceUuid]),
                        );
                      } else {
                        return StatusScreen(bleCentral: bleCentral);
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        // bottomNavigationBar: _BottomBar(initialFen),
      ),
    );
  }
}
