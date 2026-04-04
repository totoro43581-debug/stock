import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/view/stock_screen.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

import 'widget/bottom_notice_section.dart';
import 'widget/category_grid_section.dart';
import 'widget/feature_section.dart';
import 'widget/hero_section.dart';
import '../../auth/view/widget/login_card_section.dart';
import 'widget/my_asset_card_section.dart';
import '../../auth/view/widget/register_view_section.dart';
import 'widget/top_header_section.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showRegisterView = false;
  String _selectedMenu = 'home';

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
  String? _errorMessage;

  StreamSubscription<AuthState>? _authStateSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    _authStateSubscription =
        _supabase.auth.onAuthStateChange.listen((AuthState data) {
          if (!mounted) return;

          setState(() {
            if (data.session != null) {
              _showRegisterView = false;
              _errorMessage = null;
            }
          });
        });
  }

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

    _authStateSubscription?.cancel();
    super.dispose();
  }

  void _openRegisterView() {
    setState(() {
      _showRegisterView = true;
      _errorMessage = null;
    });
  }

  void _closeRegisterView() {
    setState(() {
      _showRegisterView = false;
      _errorMessage = null;
    });
  }

  Future<bool> _checkIdDuplicate(String loginId) async {
    final String trimmedId = loginId.trim();

    if (trimmedId.isEmpty) {
      return false;
    }

    try {
      final dynamic result = await _supabase
          .from('profiles')
          .select('login_id')
          .eq('login_id', trimmedId)
          .maybeSingle();

      return result == null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _checkEmailDuplicate(String email) async {
    final String trimmedEmail = email.trim();

    if (trimmedEmail.isEmpty) {
      return false;
    }

    try {
      final dynamic result = await _supabase
          .from('profiles')
          .select('email')
          .eq('email', trimmedEmail)
          .maybeSingle();

      return result == null;
    } catch (_) {
      return false;
    }
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

      final AuthResponse authResponse = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final User? user = authResponse.user;

      if (user == null) {
        throw Exception('로그인 사용자 정보를 가져오지 못했습니다.');
      }

// 수정8차: 로그인 직후 wallet 자동 생성 보장
      await WalletRepository().ensureWallet(user.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인되었습니다.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      String message = '로그인 중 오류가 발생했습니다.';

      if (e.message.contains('Invalid login credentials')) {
        message = '비밀번호가 다릅니다.';
      } else if (e.message.contains('Email not confirmed')) {
        message = '이메일 인증이 완료되지 않았습니다.';
      } else if (e.message.isNotEmpty) {
        message = e.message;
      }

      setState(() {
        _errorMessage = message;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
        e.message.isNotEmpty ? e.message : '로그인 중 오류가 발생했습니다.';
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
        _isLoading = false;
        _errorMessage = null;
        _showRegisterView = false;
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

  void _handleMenuSelected(String menuKey) {
    setState(() {
      _selectedMenu = menuKey;
      _showRegisterView = false;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Session? session = _supabase.auth.currentSession;
    final User? user = _supabase.auth.currentUser;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F9),
      body: Column(
        children: [
          TopHeaderSection(
            session: session,
            selectedMenu: _selectedMenu,
            onMenuSelected: _handleMenuSelected,
          ),
          Expanded(
            child: _showRegisterView
                ? RegisterViewSection(
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
              onTapLogin: _closeRegisterView,
              onCheckId: _checkIdDuplicate,
              onCheckEmail: _checkEmailDuplicate,
            )
                : _buildMainContent(
              session: session,
              user: user,
              isWide: isWide,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent({
    required Session? session,
    required User? user,
    required bool isWide,
  }) {
    switch (_selectedMenu) {
      case 'stock':
        return const StockScreen();

      case 'etf':
        return _buildPreparingContent('ETF');

      case 'saving':
        return _buildPreparingContent('예금/적금');

      case 'real_estate':
        return _buildPreparingContent('부동산');

      case 'report':
        return _buildPreparingContent('리포트');

      case 'asset':
        return _buildPreparingContent('자산현황');

      case 'home':
      default:
        return _buildHomeContent(
          session: session,
          user: user,
          isWide: isWide,
        );
    }
  }

  Widget _buildHomeContent({
    required Session? session,
    required User? user,
    required bool isWide,
  }) {
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isWide)
                  SizedBox(
                    height: 342,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 7,
                          child: HeroSection(
                            user: user,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          flex: 3,
                          child: session == null
                              ? LoginCardSection(
                            idController: _loginIdController,
                            passwordController: _loginPasswordController,
                            errorMessage: _errorMessage,
                            isLoading: _isLoading,
                            onTapLogin: _handleLogin,
                            onTapRegister: _openRegisterView,
                          )
                              : MyAssetCardSection(
                            user: user,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      HeroSection(user: user),
                      const SizedBox(height: 20),
                      session == null
                          ? LoginCardSection(
                        idController: _loginIdController,
                        passwordController: _loginPasswordController,
                        errorMessage: _errorMessage,
                        isLoading: _isLoading,
                        onTapLogin: _handleLogin,
                        onTapRegister: _openRegisterView,
                      )
                          : MyAssetCardSection(
                        user: user,
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                CategoryGridSection(
                  onTapStock: () => _handleMenuSelected('stock'),
                  onTapEtf: () => _handleMenuSelected('etf'),
                  onTapSaving: () => _handleMenuSelected('saving'),
                  onTapRealEstate: () => _handleMenuSelected('real_estate'),
                  onTapReport: () => _handleMenuSelected('report'),
                  onTapAsset: () => _handleMenuSelected('asset'),
                ),
                const SizedBox(height: 20),
                const FeatureSection(),
                const SizedBox(height: 20),
                const BottomNoticeSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreparingContent(String title) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF3F5F9),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.construction_rounded,
                  size: 42,
                  color: Color(0xFF2563EB),
                ),
                const SizedBox(height: 16),
                Text(
                  '$title 화면 준비중',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$title 화면은 상단 메뉴와 홈 카드 버튼에서 동일하게 연결되도록 준비 중입니다.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}