import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lichess_mobile/src/model/bluetooth/option.dart';
import 'package:lichess_mobile/src/model/bluetooth/peripheral.dart';
import 'package:lichess_mobile/src/styles/styles.dart';
import 'package:lichess_mobile/src/view/bluetooth/ui_consts.dart';
import 'package:lichess_mobile/src/widgets/list.dart';
import 'package:lichess_mobile/src/widgets/settings.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({required this.peripheral, super.key});

  final Peripheral peripheral;

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  StreamSubscription<void>? _subscription;

  Peripheral get peripheral => widget.peripheral;
  bool get areOptionsInitialized => peripheral.areOptionsInitialized;
  List<Option> get options => peripheral.options;

  @override
  void initState() {
    super.initState();
    _subscription = peripheral.optionsUpdateStream.listen(_updateOptions);
    peripheral.handleOptionsBegin();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _updateOptions(_) {
    setState(() {});
  }

  String _convertToReadable(String str) =>
      str.split('_').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');

  Widget _createTitle(Option option) => Text(_convertToReadable(option.name));

  Widget _createBoolOption(BoolOption option) => ListTile(
    title: _createTitle(option),
    trailing: Switch(
      value: option.value,
      onChanged: (bool value) {
        setState(() {
          option.value = value;
        });
      },
    ),
  );

  Widget _createEnumOption(EnumOption option) => ListTile(
    title: _createTitle(option),
    trailing: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.25),
      child: Text(
        _convertToReadable(option.valueString),
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.end,
        maxLines: 2,
      ),
    ),
    onTap: () => _showEnumOptionPicker(
      context,
      option: option,
      onSelected: (String value) {
        setState(() {
          option.value = value;
        });
      },
    ),
  );

  Widget _createStrOption(StrOption option) => ListTile(
    title: _createTitle(option),
    subtitle: Text(
      option.valueString,
      maxLines: 5,
      style: ListTileTheme.of(
        context,
      ).subtitleTextStyle?.copyWith(fontSize: Theme.of(context).textTheme.bodySmall?.fontSize),
    ),
    onTap: () => _showStrOptionPicker(
      context,
      option: option,
      onSelected: (String value) {
        setState(() {
          option.value = value;
        });
      },
    ),
  );

  Widget _createIntOption(IntOption option) => ListTile(
    title: Row(
      children: [
        _createTitle(option),
        const Text(': '),
        Text(option.valueString, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
    subtitle: Slider(
      value: option.value.toDouble(),
      min: option.min.toDouble(),
      max: option.max.toDouble(),
      divisions: ((option.max - option.min) / (option.step != null ? option.step! : 1)).round(),
      label: option.valueString,
      onChanged: (double value) {
        setState(() {
          option.value = value.toInt();
        });
      },
      year2023: false,
    ),
  );

  Widget _createFloatOption(FloatOption option) => ListTile(
    title: Row(
      children: [
        _createTitle(option),
        const Text(': '),
        Text(option.valueString, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
    subtitle: Slider(
      value: option.value,
      min: option.min,
      max: option.max,
      divisions: ((option.max - option.min) / (option.step != null ? option.step! : 0.01)).round(),
      label: option.valueString,
      onChanged: (double value) {
        setState(() {
          option.value = value;
        });
      },
      year2023: false,
    ),
  );

  Widget _createOption(Option option) {
    if (option is BoolOption) {
      return _createBoolOption(option);
    } else if (option is EnumOption) {
      return _createEnumOption(option);
    } else if (option is StrOption) {
      return _createStrOption(option);
    } else if (option is IntOption) {
      return _createIntOption(option);
    } else if (option is FloatOption) {
      return _createFloatOption(option);
    } else {
      return const SizedBox.shrink();
    }
  }

  void _showEnumOptionPicker(
    BuildContext context, {
    required EnumOption option,
    required void Function(String choice) onSelected,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.only(top: 12),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: option.enumValues
                .map((value) {
                  return RadioListTile(
                    title: Text(_convertToReadable(value)),
                    value: value,
                    groupValue: option.value,
                    onChanged: (value) {
                      if (value != null) onSelected(value);
                      Navigator.of(context).pop();
                    },
                  );
                })
                .toList(growable: false),
          ),
          actions: [
            ElevatedButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showStrOptionPicker(
    BuildContext context, {
    required StrOption option,
    required void Function(String choice) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: option.value);
        return AlertDialog(
          content: TextFormField(
            controller: controller,
            autofocus: true,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'Enter a value'),
            onFieldSubmitted: (String value) {
              onSelected(value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                onSelected(controller.text);
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionsList() => ListView(
    children: [
      ListSection(
        header: const SettingsSectionTitle('Options'),
        margin: EdgeInsets.zero,
        hasLeading: false,
        children: [Column(children: options.map(_createOption).toList())],
      ),
    ],
  );

  Widget _buildOptionsResetButton() => FilledButton.icon(
    icon: const Icon(Icons.cached_rounded),
    label: const Text('Default'),
    onPressed: areOptionsInitialized ? peripheral.handleOptionsReset : null,
  );

  Widget _buildControlButtons() => SizedBox(
    height: kBluetoothButtonHeight,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Expanded(child: _buildOptionsResetButton())],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return areOptionsInitialized
        ? Column(
            children: [
              Expanded(child: _buildOptionsList()),
              Padding(padding: Styles.sectionTopPadding, child: _buildControlButtons()),
            ],
          )
        : const SizedBox.shrink();
  }
}
