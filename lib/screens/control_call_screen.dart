import 'package:flutter/material.dart';

class ControlCallScreen extends StatelessWidget {
  const ControlCallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control Call')),
      body: const Center(child: Text('Halaman Control Call')),
    );
  }
}
