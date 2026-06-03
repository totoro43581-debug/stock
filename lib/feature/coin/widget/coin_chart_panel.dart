import 'package:flutter/material.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';

class CoinChartPanel extends StatelessWidget {
  final CoinItemModel? coin;

  const CoinChartPanel({
    super.key,
    required this.coin,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUp = (coin?.changeRate ?? 0) >= 0;

    return Container(
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          _buildChartToolbar(),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              color: Colors.white,
              child: coin == null
                  ? _buildEmptyText('선택된 코인이 없습니다.')
                  : CustomPaint(
                painter: _UpbitLikeChartPainter(
                  isUp: isUp,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _buildChartBottomToolbar(),
        ],
      ),
    );
  }

  Widget _buildChartToolbar() {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
          children: [
            _buildChartPeriodButton('1분', false),
            _buildChartPeriodButton('5분', false),
            _buildChartPeriodButton('30분', false),
            _buildChartPeriodButton('1시간', false),
            _buildChartPeriodButton('일', true),
            _buildChartPeriodButton('월', false),
            const SizedBox(width: 18),
            const Text(
              '기본차트',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBottomToolbar() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: const Row(
        children: [
          Text(
            '30일',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(width: 16),
          Text(
            '5일',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(width: 16),
          Text(
            '1일',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          Spacer(),
          Text(
            '자동',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartPeriodButton(String label, bool selected) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: selected
            ? const Border(
          bottom: BorderSide(
            color: Color(0xFF2563EB),
            width: 2,
          ),
        )
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
          color: selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _buildEmptyText(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  BoxDecoration _exchangePanelDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFDDE3EA)),
    );
  }
}

class _UpbitLikeChartPainter extends CustomPainter {
  final bool isUp;

  const _UpbitLikeChartPainter({
    required this.isUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.8;

    final Paint upPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final Paint downPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final Paint volumeUpPaint = Paint()
      ..color = const Color(0x66DC2626)
      ..style = PaintingStyle.fill;

    final Paint volumeDownPaint = Paint()
      ..color = const Color(0x662563EB)
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= 5; i++) {
      final double y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 1; i <= 8; i++) {
      final double x = size.width * i / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final double candleAreaHeight = size.height * 0.76;
    final double volumeTop = size.height * 0.80;
    final double volumeHeight = size.height * 0.18;

    const int count = 34;
    final double gap = size.width / count;
    final double baseY = candleAreaHeight * (isUp ? 0.62 : 0.38);

    for (int i = 0; i < count; i++) {
      final bool up = i % 3 != 0;
      final double x = gap * i + gap * 0.5;

      final double wave = ((i % 7) - 3) * 5;
      final double trend = isUp ? -i * 2.5 : i * 2.5;
      final double centerY = (baseY + wave + trend).clamp(
        30,
        candleAreaHeight - 24,
      );

      final double highY = (centerY - 18 - (i % 4) * 3).clamp(
        18,
        candleAreaHeight,
      );
      final double lowY = (centerY + 18 + (i % 5) * 2).clamp(
        18,
        candleAreaHeight,
      );
      final double openY = up ? centerY + 9 : centerY - 9;
      final double closeY = up ? centerY - 9 : centerY + 9;

      final Paint candlePaint = up ? upPaint : downPaint;
      final Paint volumePaint = up ? volumeUpPaint : volumeDownPaint;

      canvas.drawLine(Offset(x, highY), Offset(x, lowY), candlePaint);

      final Rect bodyRect = Rect.fromLTRB(
        x - 4,
        openY < closeY ? openY : closeY,
        x + 4,
        openY > closeY ? openY : closeY,
      );

      canvas.drawRect(bodyRect, Paint()..color = candlePaint.color);

      final double volumeRatio = 0.2 + (i % 8) * 0.09;
      final Rect volumeRect = Rect.fromLTWH(
        x - 4,
        volumeTop + volumeHeight * (1 - volumeRatio),
        8,
        volumeHeight * volumeRatio,
      );

      canvas.drawRect(volumeRect, volumePaint);
    }

    final Paint currentPricePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1;

    final double currentY = candleAreaHeight * (isUp ? 0.35 : 0.65);

    canvas.drawLine(
      Offset(0, currentY),
      Offset(size.width, currentY),
      currentPricePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _UpbitLikeChartPainter oldDelegate) {
    return oldDelegate.isUp != isUp;
  }
}