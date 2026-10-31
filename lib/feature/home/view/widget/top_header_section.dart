import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class TopHeaderSection extends StatelessWidget {
  final Session? session;
  final String selectedMenu;
  final ValueChanged<String> onMenuSelected;

  const TopHeaderSection({
    super.key,
    required this.session,
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  static const List<_HeaderMenuItem> _menus = [
    _HeaderMenuItem(text: '홈', menuKey: 'home'),
    _HeaderMenuItem(text: '자산', menuKey: 'asset'),
    _HeaderMenuItem(text: '은행', menuKey: 'bank'),
    _HeaderMenuItem(text: '주식', menuKey: 'stock'),
    _HeaderMenuItem(text: '코인', menuKey: 'coin'),
    _HeaderMenuItem(text: '부동산', menuKey: 'real_estate'),
    _HeaderMenuItem(text: '리포트', menuKey: 'report'),
    _HeaderMenuItem(text: '커뮤니티', menuKey: 'board'),
  ];

  @override
  Widget build(BuildContext context) {
    final User? user = Supabase.instance.client.auth.currentUser;

    final String displayName =
        user?.userMetadata?['user_name']?.toString() ?? '사용자';

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isCompact = width < 1160;
        final bool isMobile = width < 620;

        return Container(
          height: isMobile ? 68 : 76,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24),
            child: Row(
              children: [
                _LogoSection(
                  isMobile: isMobile,
                  onTap: () => onMenuSelected('home'),
                ),
                if (width >= 440) ...[
                  const SizedBox(width: 12),
                  const _GameClockPanel(),
                ],
                const Spacer(),
                if (!isCompact) ...[
                  for (int i = 0; i < _menus.length; i++) ...[
                    _HeaderMenuButton(
                      text: _menus[i].text,
                      menuKey: _menus[i].menuKey,
                      selectedMenu: selectedMenu,
                      onTap: onMenuSelected,
                    ),
                    if (i != _menus.length - 1) const SizedBox(width: 26),
                  ],
                  const SizedBox(width: 24),
                  _UserBadge(session: session, displayName: displayName),
                ] else ...[
                  _UserBadge(
                    session: session,
                    displayName: displayName,
                    isCompact: true,
                  ),
                  const SizedBox(width: 8),
                  _CompactMenuButton(
                    selectedMenu: selectedMenu,
                    onMenuSelected: onMenuSelected,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderMenuItem {
  final String text;
  final String menuKey;

  const _HeaderMenuItem({required this.text, required this.menuKey});
}

class _LogoSection extends StatelessWidget {
  final bool isMobile;
  final VoidCallback onTap;

  const _LogoSection({required this.isMobile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: isMobile ? 38 : 42,
            height: isMobile ? 38 : 42,
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
          if (!isMobile)
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
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserBadge extends StatelessWidget {
  final Session? session;
  final String displayName;
  final bool isCompact;

  const _UserBadge({
    required this.session,
    required this.displayName,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final String text = session == null
        ? '비로그인'
        : isCompact
        ? displayName
        : '$displayName님';

    return Container(
      constraints: BoxConstraints(maxWidth: isCompact ? 96 : 160),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 10 : 14,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: session == null
            ? const Color(0xFFF3F4F6)
            : const Color(0xFFDBEAFE),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: session == null
              ? const Color(0xFF4B5563)
              : const Color(0xFF1D4ED8),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CompactMenuButton extends StatelessWidget {
  final String selectedMenu;
  final ValueChanged<String> onMenuSelected;

  const _CompactMenuButton({
    required this.selectedMenu,
    required this.onMenuSelected,
  });

  static const List<_HeaderMenuItem> _menus = [
    _HeaderMenuItem(text: '홈', menuKey: 'home'),
    _HeaderMenuItem(text: '자산현황', menuKey: 'asset'),
    _HeaderMenuItem(text: '계좌', menuKey: 'account'),
    _HeaderMenuItem(text: '주식', menuKey: 'stock'),
    _HeaderMenuItem(text: '코인', menuKey: 'coin'),
    _HeaderMenuItem(text: '부동산', menuKey: 'real_estate'),
    _HeaderMenuItem(text: '리포트', menuKey: 'report'),
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '메뉴',
      color: Colors.white,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: onMenuSelected,
      itemBuilder: (context) {
        return [
          for (final menu in _menus)
            PopupMenuItem<String>(
              value: menu.menuKey,
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: selectedMenu == menu.menuKey
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Color(0xFF2563EB),
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    menu.text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selectedMenu == menu.menuKey
                          ? FontWeight.w900
                          : FontWeight.w700,
                      color: selectedMenu == menu.menuKey
                          ? const Color(0xFF111827)
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: const Icon(Icons.menu_rounded, color: Color(0xFF111827)),
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

class _GameClockPanel extends StatefulWidget {
  const _GameClockPanel();

  @override
  State<_GameClockPanel> createState() => _GameClockPanelState();
}

class _GameClockPanelState extends State<_GameClockPanel> {
  Timer? _timer;

  DateTime? _serverGameTime;
  DateTime? _syncRealTime;

  double _gameSecondsPerRealSecond = 60;

  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _syncClock();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {});

      // 1분마다 서버 시각으로 다시 동기화
      if (timer.tick % 60 == 0) {
        _syncClock();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _syncClock() async {
    try {
      final requestStarted = DateTime.now().toUtc();

      final response = await Supabase.instance.client.rpc('get_game_clock');

      final requestFinished = DateTime.now().toUtc();

      if (response is! Map) {
        throw StateError('게임 시계 응답이 올바르지 않습니다.');
      }

      final data = Map<String, dynamic>.from(response);

      final parsed = DateTime.tryParse(data['game_datetime']?.toString() ?? '');

      if (parsed == null) {
        throw StateError('게임 시간을 읽을 수 없습니다.');
      }

      final rawSpeed = data['game_seconds_per_real_second'];
      final speed = rawSpeed is num
          ? rawSpeed.toDouble()
          : double.tryParse(rawSpeed?.toString() ?? '') ?? 60;

      final networkHalf =
          requestFinished.difference(requestStarted).inMicroseconds ~/ 2;

      if (!mounted) return;

      setState(() {
        _serverGameTime = parsed.toUtc();
        _syncRealTime = requestStarted.add(Duration(microseconds: networkHalf));
        _gameSecondsPerRealSecond = speed;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _failed = true;
      });
    }
  }

  DateTime? get _currentGameTime {
    final startGame = _serverGameTime;
    final startReal = _syncRealTime;

    if (startGame == null || startReal == null) {
      return null;
    }

    final elapsed = DateTime.now().toUtc().difference(startReal).inMilliseconds;

    final safeElapsed = elapsed < 0 ? 0 : elapsed;

    return startGame.add(
      Duration(milliseconds: (safeElapsed * _gameSecondsPerRealSecond).round()),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final gameNow = _currentGameTime?.toLocal();

    if (gameNow == null) {
      return SizedBox(
        width: 182,
        child: Text(
          _failed ? '게임 시간 조회 실패' : '게임 시간 동기화 중',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
        ),
      );
    }

    final dateText =
        '${gameNow.year}.${_two(gameNow.month)}.'
        '${_two(gameNow.day)} '
        '${_two(gameNow.hour)}:${_two(gameNow.minute)}';

    return Container(
      width: 182,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '게임 시간',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            dateText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
