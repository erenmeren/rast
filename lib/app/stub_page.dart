import 'package:flutter/material.dart';

/// Temporary page used until a feature's real page lands.
class StubPage extends StatelessWidget {
  const StubPage(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: Text(title))));
}
