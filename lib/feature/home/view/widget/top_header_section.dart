import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TopHeaderSection extends StatelessWidget {
  final Session? session;

  // 수정18차: 현재 선택 메뉴
  final String selectedMenu;

  // 수정18차: 메뉴 클릭 콜백
  final ValueChanged<String> onMenuSelected;

  const TopHeaderSection({
    super.key,
    required this.session,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final User? user = Supabase.instance.client.auth.currentUser;

    final String displayName =
        user?.userMetadata?['user_name']?.toString() ?? '사용자';

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onMenuSelected('home'),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D4ED8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock Web Game',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '경제 활동 모의 플랫폼',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(),
            _HeaderMenuButton(
              text: '홈',
              menuKey: 'home',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 28),
            _HeaderMenuButton(
              text: '자산현황',
              menuKey: 'asset',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 28),

            // 수정18차: 예금/적금을 상위 메뉴에서 제거하고 계좌로 통합
            // 라우팅은 기존 BankScreen 연결 유지를 위해 saving key 임시 유지
            _HeaderMenuButton(
              text: '계좌',
              menuKey: 'saving',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 28),
            _HeaderMenuButton(
              text: '주식',
              menuKey: 'stock',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 28),
            _HeaderMenuButton(
              text: '부동산',
              menuKey: 'real_estate',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 28),
            _HeaderMenuButton(
              text: '리포트',
              menuKey: 'report',
              selectedMenu: selectedMenu,
              onTap: onMenuSelected,
            ),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: session == null
                    ? const Color(0xFFF3F4F6)
                    : const Color(0xFFDBEAFE),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                session == null ? '비로그인' : '$displayName님',
                style: TextStyle(
                  color: session == null
                      ? const Color(0xFF4B5563)
                      : const Color(0xFF1D4ED8),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMenuButton extends StatelessWidget {
  final String text;
  final String menuKey;
  final String selectedMenu;
  final ValueChanged<String> onTap;

  const _HeaderMenuButton({
    required this.text,
    required this.menuKey,
    required this.selectedMenu,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedMenu == menuKey;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => onTap(menuKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF111827)
                    : const Color(0xFF374151),
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isSelected ? 24 : 0,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}