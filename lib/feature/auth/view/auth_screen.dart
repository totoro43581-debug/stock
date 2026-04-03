import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/auth/view/widget/login_card_section.dart';
import 'package:stock/feature/auth/view/widget/register_view_section.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController =
  TextEditingController();

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

  Future<bool> _checkIdDuplicate(String id) async {
    final String trimmedId = id.trim();

    debugPrint('수정1차 _checkIdDuplicate 호출됨: $trimmedId');

    if (trimmedId.isEmpty) {
      return false;
    }

    final Map<String, dynamic>? result = await _supabase
        .from('profiles')
        .select('id')
        .eq('login_id', trimmedId)
        .maybeSingle();

    debugPrint('수정1차 _checkIdDuplicate result: $result');

    return result == null;
  }

  Future<bool> _checkEmailDuplicate(String email) async {
    final String trimmedEmail = email.trim();

    debugPrint('수정1차 _checkEmailDuplicate 호출됨: $trimmedEmail');

    if (trimmedEmail.isEmpty) {
      return false;
    }

    final Map<String, dynamic>? result = await _supabase
        .from('profiles')
        .select('id')
        .eq('email', trimmedEmail)
        .maybeSingle();

    debugPrint('수정1차 _checkEmailDuplicate result: $result');

    return result == null;
  }

  Future<String?> _findEmailByLoginId(String loginId) async {
    final String trimmedId = loginId.trim();

    if (trimmedId.isEmpty) {
      return null;
    }

    final Map<String, dynamic>? result = await _supabase
        .from('profiles')
        .select('email')
        .eq('login_id', trimmedId)
        .maybeSingle();

    if (result == null) {
      return null;
    }

    return result['email']?.toString();
  }

  Future<void> _handleLogin() async {
    final String loginId = _loginIdController.text.trim();
    final String password = _loginPasswordController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (loginId.isEmpty || password.isEmpty) {
        throw Exception('아이디와 비밀번호를 입력해주세요.');
      }

      final String? email = await _findEmailByLoginId(loginId);

      if (email == null || email.isEmpty) {
        throw Exception('존재하지 않는 아이디입니다.');
      }

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인되었습니다.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = e.message;

      // 수정4차: contains로 변경 (핵심)
      if (e.message.toLowerCase().contains('Invalid login credentials')) {
        message = '아이디 또는 비밀번호가 다릅니다.';
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    final String loginId = _registerIdController.text.trim();
    final String password = _registerPasswordController.text.trim();
    final String passwordConfirm =
    _registerPasswordConfirmController.text.trim();
    final String userName = _registerUserNameController.text.trim();
    final String phone = _registerPhoneController.text.trim();
    final String email = _registerEmailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (loginId.isEmpty ||
          password.isEmpty ||
          passwordConfirm.isEmpty ||
          userName.isEmpty ||
          phone.isEmpty ||
          email.isEmpty) {
        throw Exception('회원가입 항목을 모두 입력해주세요.');
      }

      if (password != passwordConfirm) {
        throw Exception('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
      }

      final bool isIdAvailable = await _checkIdDuplicate(loginId);
      if (!isIdAvailable) {
        throw Exception('이미 사용 중인 ID입니다.');
      }

      final bool isEmailAvailable = await _checkEmailDuplicate(email);
      if (!isEmailAvailable) {
        throw Exception('이미 사용 중인 이메일입니다.');
      }

      final AuthResponse authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'login_id': loginId,
          'user_name': userName,
          'phone': phone,
        },
      );

      final User? createdUser = authResponse.user;

      if (createdUser == null) {
        throw Exception('회원가입은 완료되었지만 사용자 정보를 가져오지 못했습니다.');
      }

      await _supabase.from('profiles').upsert({
        'id': createdUser.id,
        'login_id': loginId,
        'user_name': userName,
        'phone': phone,
        'email': email,
        'role': 'user',
        'agree_terms': true,
        'agree_privacy': true,
        'agree_marketing': false,
      });

      if (!mounted) return;

      _registerIdController.clear();
      _registerPasswordController.clear();
      _registerPasswordConfirmController.clear();
      _registerUserNameController.clear();
      _registerPhoneController.clear();
      _registerEmailController.clear();

      setState(() {
        _showRegister = false;
        _errorMessage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인해 주세요.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;

      String message = '회원가입 중 오류가 발생했습니다.';

      if (e.message.contains('duplicate key') &&
          e.message.contains('login_id')) {
        message = '이미 사용 중인 ID입니다.';
      } else if (e.message.contains('duplicate key') &&
          e.message.contains('email')) {
        message = '이미 사용 중인 이메일입니다.';
      } else if (e.message.isNotEmpty) {
        message = e.message;
      }

      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
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
              onCheckId: _checkIdDuplicate,
              onCheckEmail: _checkEmailDuplicate,
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