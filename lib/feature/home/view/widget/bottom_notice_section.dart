import 'package:flutter/material.dart';

class BottomNoticeSection extends StatelessWidget {
  const BottomNoticeSection({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width >= 900;
        final bool isMobile = width < 620;

        final double padding = isMobile ? 18 : 22;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: const Color(0xFF111827),
            borderRadius: BorderRadius.circular(20),
          ),
          child: isDesktop
              ? Row(
            children: [
              const Expanded(
                flex: 3,
                child: _NoticeTitleBlock(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 7,
                child: _NoticeContentBlock(
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          )
              : const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NoticeTitleBlock(),
              SizedBox(height: 14),
              _NoticeContentBlock(
                textAlign: TextAlign.left,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoticeTitleBlock extends StatelessWidget {
  const _NoticeTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.info_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            '현재 진행 상태',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoticeContentBlock extends StatelessWidget {
  const _NoticeContentBlock({
    required this.textAlign,
  });

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      '기본 자산계좌, 예/적금, 주식 매수·매도, 계좌 이체 흐름까지 연결되었습니다. 다음 단계에서는 코인 투자 계좌와 코인 매수·매도 화면을 연결합니다.',
      textAlign: textAlign,
      style: const TextStyle(
        color: Color(0xFFD1D5DB),
        fontSize: 14,
        height: 1.75,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}