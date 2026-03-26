import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConnectTestScreen extends StatefulWidget {
  const SupabaseConnectTestScreen({super.key});

  @override
  State<SupabaseConnectTestScreen> createState() =>
      _SupabaseConnectTestScreenState();
}

class _SupabaseConnectTestScreenState
    extends State<SupabaseConnectTestScreen> {

  String _statusMessage = '아직 테스트 안함';
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '연결 확인 중...';
    });

    try {
      final user = supabase.auth.currentUser;

      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _statusMessage = '''
연결 성공

현재 유저: ${user?.email ?? '없음'}
''';
      });
    } catch (e) {
      setState(() {
        _statusMessage = '연결 실패\n$e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_statusMessage),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _testConnection,
                child: const Text('테스트 실행'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}