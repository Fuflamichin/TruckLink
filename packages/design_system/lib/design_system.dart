import 'package:flutter/material.dart';

class TruckLinkTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0D131D),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF30C7B5),
      brightness: Brightness.dark,
      surface: const Color(0xFF172230),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF172230),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.title, required this.value, this.icon = Icons.speed});
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 6),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
      ]),
    ),
  );
}
