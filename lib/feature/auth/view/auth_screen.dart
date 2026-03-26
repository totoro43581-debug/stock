import 'package:flutter/material.dart';
import 'package:stock/feature/auth/view/widget/login_card_section.dart';
import 'package:stock/feature/auth/view/widget/register_view_section.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // 수정1차: 로그인 입력 컨트롤러
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController =
  TextEditingController();

  // 수정1차: 회원가입 입력 컨트롤러
  final TextEditingController _registerIdController = TextEditingController();
  final TextEditingController _registerPasswordController =
  TextEditingController();
  final TextEditingController _registerPasswordConfirmController =
  TextEditingController();
  final TextEditingController _registerUserNameController =
  TextEditingController();
  final TextEditingController _registerPhoneController =
  TextEditingController();
  final TextEditingController _registerEmailController =
  TextEditingController();

  // 수정1차: 상태값
  bool _isLoading = false;
  bool _showRegister = false;
  String? _errorMessage;

  @override
  void dispose() {
    _loginIdController.dispose();
    _loginPasswordController.dispose();

    _registerIdController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    _registerUserNameController.dispose();
    _registerPhoneController.dispose();
    _registerEmailController.dispose();

    super.dispose();
  }

  // 수정1차: 로그인 처리
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_loginIdController.text.trim().isEmpty ||
        _loginPasswordController.text.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '아이디와 비밀번호를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로그인 기능은 다음 단계에서 Supabase와 연결합니다.'),
      ),
    );
  }

  // 수정1차: 회원가입 처리
  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (_registerIdController.text.trim().isEmpty ||
        _registerPasswordController.text.trim().isEmpty ||
        _registerPasswordConfirmController.text.trim().isEmpty ||
        _registerUserNameController.text.trim().isEmpty ||
        _registerPhoneController.text.trim().isEmpty ||
        _registerEmailController.text.trim().isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = '회원가입 항목을 모두 입력해주세요.';
      });
      return;
    }

    if (_registerPasswordController.text.trim() !=
        _registerPasswordConfirmController.text.trim()) {
      setState(() {
        _isLoading = false;
        _errorMessage = '비밀번호와 비밀번호 확인이 일치하지 않습니다.';
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _errorMessage = null;
      _showRegister = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원가입 기능은 다음 단계에서 Supabase와 연결합니다.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showRegister
                ? RegisterViewSection(
              key: const ValueKey('register_view'),
              idController: _registerIdController,
              passwordController: _registerPasswordController,
              passwordConfirmController:
              _registerPasswordConfirmController,
              userNameController: _registerUserNameController,
              phoneController: _registerPhoneController,
              emailController: _registerEmailController,
              errorMessage: _errorMessage,
              isLoading: _isLoading,
              onSubmit: _handleRegister,
              onTapLogin: () {
                setState(() {
                  _showRegister = false;
                  _errorMessage = null;
                });
              },
            )
                : LoginCardSection(
              key: const ValueKey('login_view'),
              idController: _loginIdController,
              passwordController: _loginPasswordController,
              errorMessage: _errorMessage,
              isLoading: _isLoading,
              onTapLogin: _handleLogin,
              onTapRegister: () {
                setState(() {
                  _showRegister = true;
                  _errorMessage = null;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}