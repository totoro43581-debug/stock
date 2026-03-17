import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  Widget build(BuildContext context) {
    final SupabaseClient supabase = Supabase.instance.client;
    final Session? session = supabase.auth.currentSession;
    final User? user = supabase.auth.currentUser;

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
                : SingleChildScrollView(
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
                                  onLoginSuccess:
                                  _handleLoginSuccess,
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
            ),
          ),
        ],
      ),
    );
  }
}