import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/stock/view/stock_screen.dart';

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
  // 수정1차: HomeScreen에는 화면 전환 상태만 유지
  bool _showRegisterView = false;

  // 수정5차: 상단 메뉴 기준 메인 컨텐츠 상태
  String _selectedMenu = 'home';

  // 수정6차: 로그인 입력 컨트롤러
  final TextEditingController _loginIdController = TextEditingController();
  final TextEditingController _loginPasswordController =
  TextEditingController();

  // 수정6차: 회원가입 입력 컨트롤러
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

  // 수정6차: 로그인/회원가입 공통 상태값
  bool _isLoading = false;
  String? _errorMessage;

  // 수정3차: Supabase 인증 상태 변경 감지 리스너
  StreamSubscription<AuthState>? _authStateSubscription;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();

    // 수정3차: 로그인/로그아웃 발생 시 HomeScreen 강제 갱신
    _authStateSubscription =
        _supabase.auth.onAuthStateChange.listen((AuthState data) {
          if (!mounted) return;

          setState(() {
            // 수정3차: 로그인 성공 시 회원가입 화면 닫기
            if (data.session != null) {
              _showRegisterView = false;
              _errorMessage = null;
            }
          });
        });
  }

  @override
  void dispose() {
    // 수정6차: 컨트롤러 해제
    _loginIdController.dispose();
    _loginPasswordController.dispose();
    _registerIdController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    _registerUserNameController.dispose();
    _registerPhoneController.dispose();
    _registerEmailController.dispose();

    // 수정3차: 리스너 해제
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // 수정2차: 회원가입 화면 열기
  void _openRegisterView() {
    setState(() {
      _showRegisterView = true;
      _errorMessage = null;
    });
  }

  // 수정2차: 회원가입 화면 닫기
  void _closeRegisterView() {
    setState(() {
      _showRegisterView = false;
      _errorMessage = null;
    });
  }

  // 수정6차: 로그인 처리
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

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

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('로그인 연결은 다음 단계에서 Supabase와 연동합니다.'),
      ),
    );
  }

  // 수정6차: 회원가입 처리
  Future<void> _handleRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

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
      _showRegisterView = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('회원가입 연결은 다음 단계에서 Supabase와 연동합니다.'),
      ),
    );
  }

  // 수정5차: 상단 메뉴 선택 처리
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

  // 수정5차: 상단 메뉴 기준 메인 컨텐츠 분기
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

  // 수정4차: 기존 홈 메인 컨텐츠
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

  // 수정5차: 준비중 화면
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