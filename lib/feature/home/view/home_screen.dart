import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../stock/view/stock_screen.dart';
import 'widget/bottom_notice_section.dart';
import 'widget/category_grid_section.dart';
import 'widget/feature_section.dart';
import 'widget/hero_section.dart';
import 'widget/login_card_section.dart';
import 'widget/my_asset_card_section.dart';
import 'widget/register_view_section.dart';
import 'widget/top_header_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 수정1차: HomeScreen에는 화면 전환 상태만 유지
  bool _showRegisterView = false;

  // 수정4차: 메인 컨텐츠 전환 상태
  String _selectedContent = 'home';

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
            }
          });
        });
  }

  @override
  void dispose() {
    // 수정3차: 리스너 해제
    _authStateSubscription?.cancel();
    super.dispose();
  }

  // 수정2차: 회원가입 화면 열기
  void _openRegisterView() {
    setState(() {
      _showRegisterView = true;
    });
  }

  // 수정2차: 회원가입 화면 닫기
  void _closeRegisterView() {
    setState(() {
      _showRegisterView = false;
    });
  }

  // 수정2차: 로그인 성공 처리
  void _handleLoginSuccess() {
    setState(() {
      _showRegisterView = false;
    });
  }

  // 수정4차: 홈 메인으로 이동
  void _goHomeContent() {
    setState(() {
      _selectedContent = 'home';
    });
  }

  // 수정4차: 주식 화면으로 이동
  void _openStockScreen() {
    setState(() {
      _selectedContent = 'stock';
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
          TopHeaderSection(session: session),
          Expanded(
            child: _showRegisterView
                ? RegisterViewSection(
              onCloseRegisterView: _closeRegisterView,
            )
                : _selectedContent == 'stock'
                ? _buildStockContent()
                : _buildHomeContent(
              session: session,
              user: user,
              isWide: isWide,
            ),
          ),
        ],
      ),
    );
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
                          onOpenRegister: _openRegisterView,
                          onLoginSuccess: _handleLoginSuccess,
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
                        onOpenRegister: _openRegisterView,
                        onLoginSuccess: _handleLoginSuccess,
                      )
                          : MyAssetCardSection(
                        user: user,
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // 수정4차: 카테고리 영역 위에 임시 화면 전환 버튼 추가
                _buildContentShortcutSection(),

                const SizedBox(height: 20),

                // 수정4차: 기존 카테고리 섹션 유지
                const CategoryGridSection(),

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

  // 수정4차: 주식 화면 메인 컨텐츠
  Widget _buildStockContent() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _goHomeContent,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('홈으로'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '주식 화면',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(
          child: StockScreen(),
        ),
      ],
    );
  }

  // 수정4차: 홈에서 주식 화면으로 진입하는 임시 바로가기
  Widget _buildContentShortcutSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              color: Color(0xFF4F46E5),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주식 탭 바로가기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '기존 홈 화면 구조는 유지하고, 메인 컨텐츠 영역 안에서 주식 화면으로 전환합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _openStockScreen,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '주식 열기',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}