import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cardio Rounds')),
      body: const Center(
        child: Text('Scaffold ready. Database and screens coming next.'),
      ),
    );
  }
}
