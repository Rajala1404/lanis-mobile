import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../client/storage.dart';

class CountlySettingsScreen extends StatelessWidget {
  const CountlySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.telemetry),
        ),
        body: const Body());
  }
}

class Body extends StatefulWidget {
  const Body({super.key});

  @override
  State<Body> createState() => _BodyState();
}

class _BodyState extends State<Body> {
  bool enabled = true;

  @override
  void initState() {
    super.initState();
    globalStorage.read(key: StorageKey.settingsUseCountly).then((value) {
      enabled = value == "true";
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.info),
          title: const Text('Countly Server'),
          subtitle: Text(AppLocalizations.of(context)!.settingsInfoTelemetry),
          onTap: () {
            launchUrl(Uri.parse("https://countly.com/lite"));
          },
        ),
        SwitchListTile(
            value: enabled,
            title: Text(AppLocalizations.of(context)!.sendAnonymousBugReports),
            onChanged: (state) async {
              setState(() {
                enabled = state;
              });
              await globalStorage.write(
                  key: StorageKey.settingsUseCountly, value: state.toString());
            }),
      ],
    );
  }
}
