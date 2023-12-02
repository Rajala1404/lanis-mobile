import 'package:flutter/material.dart';

import 'package:sph_plan/client/client.dart';

class SupportedFeaturesOverviewScreen extends StatefulWidget {
  const SupportedFeaturesOverviewScreen({super.key});

  @override
  State<StatefulWidget> createState() => _SupportedFeaturesOverviewScreenState();
}


final List<String> supportedApps = [
  "Vertretungsplan",
  "Kalender",
  "Logout"
];


class _SupportedFeaturesOverviewScreenState extends State<SupportedFeaturesOverviewScreen> {
  double padding = 10.0;

  List<ListTile> featureListListTiles = [];

  @override
  void initState() {
    super.initState();
    loadFeatureData();
  }

  void loadFeatureData() {
    setState(() {
      featureListListTiles.clear();

      client.supportedApps.forEach((value) {
        featureListListTiles.add(ListTile(
          leading: const Icon(Icons.settings_applications),
          iconColor: HexColor.fromHex(value["Farbe"]),
          title: Text(value["Name"]),
          subtitle: Text(supportedApps.contains(value["Name"]) ? "Unterstützt": "nicht Unterstützt"),
        ));
      });

      featureListListTiles.add(const ListTile(
        leading: Icon(Icons.info),
        title: Text("Information"),
        subtitle: Text("Jede Schule hat andere Apps. Deine Schule verfügt über die hier aufgelisteten Apps. Nicht alle Apps werden von dieser App unterstützt. Wenn eine App nicht wie erwartet funktioniert, kontaktiere bitte den Entwickler der App. Wahrscheinlich gibt es ein Problem mit deiner Schule, das behoben werden kann."),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Unterstützung"),
      ),
      body: ListView(
        children: featureListListTiles,
      ),
    );
  }
}

extension HexColor on Color {
  /// String is in the format "aabbcc" or "ffaabbcc" with an optional leading "#".
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Prefixes a hash sign if [leadingHashSign] is set to `true` (default is `true`).
  String toHex({bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      '${alpha.toRadixString(16).padLeft(2, '0')}'
      '${red.toRadixString(16).padLeft(2, '0')}'
      '${green.toRadixString(16).padLeft(2, '0')}'
      '${blue.toRadixString(16).padLeft(2, '0')}';
}