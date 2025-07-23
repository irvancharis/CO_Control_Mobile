import 'package:flutter/material.dart';

class JoinCallScreen extends StatelessWidget {
  const JoinCallScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Call')),
      body: const Center(child: Text('Halaman Join Call')),
    );
  }
}
