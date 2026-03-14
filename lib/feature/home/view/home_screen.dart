import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Web Game'),
      ),
      body: const Center(
        child: Text(
          '주식 웹게임 프로젝트 시작',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}