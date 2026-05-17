import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';

part 'bluetooth_preferences.freezed.dart';
part 'bluetooth_preferences.g.dart';

final bluetoothPreferencesProvider = NotifierProvider<BluetoothPreferencesNotifier, BluetoothPrefs>(
  BluetoothPreferencesNotifier.new,
  name: 'BluetoothPreferencesProvider',
);

class BluetoothPreferencesNotifier extends Notifier<BluetoothPrefs>
    with PreferencesStorage<BluetoothPrefs> {
  @override
  @protected
  final prefCategory = PrefCategory.bluetooth;

  @override
  @protected
  BluetoothPrefs get defaults => BluetoothPrefs.defaults;

  @override
  BluetoothPrefs fromJson(Map<String, dynamic> json) => BluetoothPrefs.fromJson(json);

  @override
  BluetoothPrefs build() {
    return fetch();
  }

  Future<void> setAutoconnect(bool autoconnect) {
    return save(state.copyWith(autoconnect: autoconnect));
  }

  Future<void> setDevice(String deviceId) {
    return save(state.copyWith(deviceId: deviceId));
  }

  Future<void> clearDevice() {
    return save(state.copyWith(deviceId: ''));
  }
}

@Freezed(fromJson: true, toJson: true)
sealed class BluetoothPrefs with _$BluetoothPrefs implements Serializable {
  const BluetoothPrefs._();

  const factory BluetoothPrefs({
    @JsonKey(defaultValue: true) required bool autoconnect,
    @JsonKey(defaultValue: '') required String deviceId,
  }) = _BluetoothPrefs;

  static const defaults = BluetoothPrefs(autoconnect: true, deviceId: '');

  factory BluetoothPrefs.fromJson(Map<String, dynamic> json) {
    return _$BluetoothPrefsFromJson(json);
  }

  bool get isDeviceSaved => deviceId.isNotEmpty;
}
