import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stock/feature/stock/model/stock_candle_model.dart';

class StockPriceChart extends StatefulWidget {
  final List<StockCandleModel> prices;

  const StockPriceChart({
    super.key,
    required this.prices,
  });

  @override
  State<StockPriceChart> createState() => _StockPriceChartState();
}

class _StockPriceChartState extends State<StockPriceChart> {
  Offset? _hoverPosition;
  String _selectedPeriod = '1주';

  final List<String> _periods = const [
    '1주',
    '1개월',
    '3개월',
    '1년',
    '전체',
  ];

  List<StockCandleModel> get _filteredCandles {
    if (widget.prices.isEmpty) return [];

    final sorted = [...widget.prices]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final latest = sorted.last.createdAt;

    Duration? range;

    switch (_selectedPeriod) {
      case '1주':
        range = const Duration(days: 7);
        break;
      case '1개월':
        range = const Duration(days: 30);
        break;
      case '3개월':
        range = const Duration(days: 90);
        break;
      case '1년':
        range = const Duration(days: 365);
        break;
      case '전체':
      default:
        return sorted;
    }

    final start = latest.subtract(range);

    final filtered = sorted.where((item) {
      return item.createdAt.isAfter(start) ||
          item.createdAt.isAtSameMomentAs(start);
    }).toList();

    return filtered.isEmpty ? sorted : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final candles = _filteredCandles;

    if (candles.isEmpty) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        decoration: _boxDecoration(),
        child: const Text(
          '차트 데이터가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    }

    final first = candles.first.open;
    final last = candles.last.close;
    final diff = last - first;
    final rate = first == 0 ? 0 : (diff / first) * 100;
    final isUp = diff >= 0;

    return Container(
      height: 500,
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 수정28차: OHLC 캔들 + 거래량 + 이동평균선 기준 현재가 영역
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₩ ${_formatPrice(last)}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${diff >= 0 ? '+' : ''}${_formatPrice(diff)}원',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isUp
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${rate >= 0 ? '+' : ''}${rate.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isUp
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periods.map((period) {
                final selected = _selectedPeriod == period;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPeriod = period;
                        _hoverPosition = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF111827)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF111827)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Text(
                        period,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 10),

          // 수정28차: 이동평균선 범례
          Row(
            children: [
              _buildLegendDot(
                label: 'MA5',
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: 12),
              _buildLegendDot(
                label: 'MA20',
                color: const Color(0xFF8B5CF6),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Expanded(
            child: MouseRegion(
              onHover: (event) {
                setState(() {
                  _hoverPosition = event.localPosition;
                });
              },
              onExit: (_) {
                setState(() {
                  _hoverPosition = null;
                });
              },
              child: CustomPaint(
                painter: _CandleChartPainter(
                  candles: candles,
                  hoverPosition: _hoverPosition,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot({
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  BoxDecoration _boxDecoration() {
    return BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE5E7EB)),
      borderRadius: BorderRadius.circular(16),
    );
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }
}

class _CandleChartPainter extends CustomPainter {
  final List<StockCandleModel> candles;
  final Offset? hoverPosition;

  _CandleChartPainter({
    required this.candles,
    required this.hoverPosition,
  });

  static const double leftPadding = 8;
  static const double rightPadding = 64;
  static const double topPadding = 14;
  static const double bottomPadding = 38;

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final chartWidth = size.width - leftPadding - rightPadding;
    final fullHeight = size.height - topPadding - bottomPadding;

    final candleHeight = fullHeight * 0.74;
    final volumeGap = 14.0;
    final volumeHeight = fullHeight * 0.20;
    final volumeTop = topPadding + candleHeight + volumeGap;

    final ma5 = _movingAverage(5);
    final ma20 = _movingAverage(20);

    final priceValues = <double>[
      ...candles.map((e) => e.low),
      ...candles.map((e) => e.high),
      ...ma5.whereType<double>(),
      ...ma20.whereType<double>(),
    ];

    final minPrice = priceValues.reduce(min);
    final maxPrice = priceValues.reduce(max);

    final priceGapRaw = maxPrice - minPrice == 0 ? 1 : maxPrice - minPrice;
    final unit = max(100, ((priceGapRaw / 4 / 100).ceil()) * 100);

    final bottomPrice = ((minPrice / unit).floor()) * unit;
    final topPrice = ((maxPrice / unit).ceil()) * unit;
    final priceGap = topPrice - bottomPrice == 0 ? 1 : topPrice - bottomPrice;

    final maxVolume = candles.map((e) => e.volume).reduce(max);
    final safeMaxVolume = maxVolume <= 0 ? 1 : maxVolume;

    double yForPrice(num price) {
      return topPadding +
          candleHeight -
          (((price - bottomPrice) / priceGap) * candleHeight);
    }

    double xForIndex(int index) {
      if (candles.length == 1) {
        return leftPadding + chartWidth / 2;
      }

      return leftPadding + (chartWidth / (candles.length - 1)) * index;
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    final axisPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    // 수정28차: Y축 가격 눈금
    for (int i = 0; i <= 4; i++) {
      final price = bottomPrice + (priceGap / 4) * i;
      final y = topPadding + candleHeight - (candleHeight / 4) * i;

      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(leftPadding + chartWidth, y),
        gridPaint,
      );

      _drawText(
        canvas: canvas,
        text: _formatPrice(price),
        offset: Offset(leftPadding + chartWidth + 8, y - 7),
        fontSize: 10,
        color: const Color(0xFF6B7280),
      );
    }

    canvas.drawLine(
      Offset(leftPadding, topPadding + candleHeight),
      Offset(leftPadding + chartWidth, topPadding + candleHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(leftPadding, volumeTop),
      Offset(leftPadding + chartWidth, volumeTop),
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..strokeWidth = 1,
    );

    _drawText(
      canvas: canvas,
      text: '거래량',
      offset: Offset(leftPadding, volumeTop + 4),
      fontSize: 10,
      color: const Color(0xFF9CA3AF),
    );

    // 수정28차: X축 날짜 눈금
    final tickCount = min(5, candles.length);

    for (int i = 0; i < tickCount; i++) {
      final ratio = tickCount == 1 ? 0.0 : i / (tickCount - 1);
      final index = ((candles.length - 1) * ratio).round();
      final x = xForIndex(index);
      final date = candles[index].createdAt;

      _drawText(
        canvas: canvas,
        text: _formatDate(date),
        offset: Offset(x - 16, topPadding + fullHeight + 12),
        fontSize: 10,
        color: const Color(0xFF6B7280),
      );
    }

    final candleSlotWidth =
    candles.length <= 1 ? chartWidth : chartWidth / candles.length;

    final candleBodyWidth = candleSlotWidth.clamp(4.0, 13.0);
    final volumeBarWidth = candleSlotWidth.clamp(3.0, 11.0);

    // 수정28차: 거래량 바
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = xForIndex(i);

      final isUp = candle.close >= candle.open;
      final color = isUp
          ? const Color(0xFFDC2626).withOpacity(0.28)
          : const Color(0xFF2563EB).withOpacity(0.28);

      final volumeRatio = candle.volume / safeMaxVolume;
      final barHeight = max(1.0, volumeHeight * volumeRatio);
      final barTop = volumeTop + volumeHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, barTop + barHeight / 2),
          width: volumeBarWidth,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    // 수정28차: OHLC 캔들
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = xForIndex(i);

      final isUp = candle.close >= candle.open;
      final candleColor =
      isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

      final highY = yForPrice(candle.high);
      final lowY = yForPrice(candle.low);
      final openY = yForPrice(candle.open);
      final closeY = yForPrice(candle.close);

      final wickPaint = Paint()
        ..color = candleColor
        ..strokeWidth = 1.3;

      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        wickPaint,
      );

      final bodyTop = min(openY, closeY);
      final bodyBottom = max(openY, closeY);
      final bodyHeight = max(2.0, bodyBottom - bodyTop);

      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, bodyTop + bodyHeight / 2),
          width: candleBodyWidth,
          height: bodyHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(
        rect,
        Paint()
          ..color = candleColor
          ..style = PaintingStyle.fill,
      );
    }

    // 수정28차: 이동평균선은 캔들 위에 표시
    _drawMovingAverageLine(
      canvas: canvas,
      values: ma5,
      color: const Color(0xFFF59E0B),
      yForPrice: yForPrice,
      xForIndex: xForIndex,
    );

    _drawMovingAverageLine(
      canvas: canvas,
      values: ma20,
      color: const Color(0xFF8B5CF6),
      yForPrice: yForPrice,
      xForIndex: xForIndex,
    );

    // 수정28차: hover 툴팁 + 선택 강조
    if (hoverPosition != null) {
      final hoverX = hoverPosition!.dx.clamp(
        leftPadding,
        leftPadding + chartWidth,
      );

      final ratio = (hoverX - leftPadding) / chartWidth;
      final index = (ratio * (candles.length - 1)).round().clamp(
        0,
        candles.length - 1,
      );

      final candle = candles[index];
      final x = xForIndex(index);

      final isUp = candle.close >= candle.open;
      final candleColor =
      isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

      final selectedY = yForPrice(candle.close);

      final hoverLinePaint = Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = 1.2;

      canvas.drawLine(
        Offset(x, topPadding),
        Offset(x, volumeTop + volumeHeight),
        hoverLinePaint,
      );

      canvas.drawCircle(
        Offset(x, selectedY),
        5,
        Paint()..color = candleColor,
      );

      final volumeRatio = candle.volume / safeMaxVolume;
      final barHeight = max(1.0, volumeHeight * volumeRatio);
      final barTop = volumeTop + volumeHeight - barHeight;

      final highlightRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, barTop + barHeight / 2),
          width: volumeBarWidth + 3,
          height: barHeight,
        ),
        const Radius.circular(2),
      );

      canvas.drawRRect(
        highlightRect,
        Paint()
          ..color = candleColor.withOpacity(0.55)
          ..style = PaintingStyle.fill,
      );

      _drawTooltip(
        canvas: canvas,
        size: size,
        point: Offset(x, selectedY),
        candle: candle,
        ma5: ma5[index],
        ma20: ma20[index],
      );
    }
  }

  List<double?> _movingAverage(int period) {
    final result = <double?>[];

    for (int i = 0; i < candles.length; i++) {
      if (i + 1 < period) {
        result.add(null);
        continue;
      }

      double sum = 0;

      for (int j = i - period + 1; j <= i; j++) {
        sum += candles[j].close;
      }

      result.add(sum / period);
    }

    return result;
  }

  void _drawMovingAverageLine({
    required Canvas canvas,
    required List<double?> values,
    required Color color,
    required double Function(num price) yForPrice,
    required double Function(int index) xForIndex,
  }) {
    final path = Path();
    bool started = false;

    for (int i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) continue;

      final x = xForIndex(i);
      final y = yForPrice(value);

      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }

    if (!started) return;

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawTooltip({
    required Canvas canvas,
    required Size size,
    required Offset point,
    required StockCandleModel candle,
    required double? ma5,
    required double? ma20,
  }) {
    const tooltipWidth = 154.0;
    const tooltipHeight = 156.0;
    const tooltipGap = 12.0;

    double tooltipX = point.dx + tooltipGap;

    if (tooltipX + tooltipWidth > size.width) {
      tooltipX = point.dx - tooltipWidth - tooltipGap;
    }

    double tooltipY = point.dy - tooltipHeight - tooltipGap;

    if (tooltipY < 0) {
      tooltipY = point.dy + tooltipGap;
    }

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        tooltipX,
        tooltipY,
        tooltipWidth,
        tooltipHeight,
      ),
      const Radius.circular(12),
    );

    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFF111827)
        ..style = PaintingStyle.fill,
    );

    final isUp = candle.close >= candle.open;
    final closeColor =
    isUp ? const Color(0xFFFCA5A5) : const Color(0xFF93C5FD);

    _drawText(
      canvas: canvas,
      text: _formatDate(candle.createdAt),
      offset: Offset(tooltipX + 10, tooltipY + 8),
      fontSize: 11,
      color: const Color(0xFFD1D5DB),
    );

    _drawText(
      canvas: canvas,
      text: '시가  ₩ ${_formatPrice(candle.open)}',
      offset: Offset(tooltipX + 10, tooltipY + 28),
      fontSize: 11,
      color: Colors.white,
    );

    _drawText(
      canvas: canvas,
      text: '고가  ₩ ${_formatPrice(candle.high)}',
      offset: Offset(tooltipX + 10, tooltipY + 45),
      fontSize: 11,
      color: Colors.white,
    );

    _drawText(
      canvas: canvas,
      text: '저가  ₩ ${_formatPrice(candle.low)}',
      offset: Offset(tooltipX + 10, tooltipY + 62),
      fontSize: 11,
      color: Colors.white,
    );

    _drawText(
      canvas: canvas,
      text: '종가  ₩ ${_formatPrice(candle.close)}',
      offset: Offset(tooltipX + 10, tooltipY + 79),
      fontSize: 11,
      color: closeColor,
      fontWeight: FontWeight.w800,
    );

    _drawText(
      canvas: canvas,
      text: '거래량  ${_formatPrice(candle.volume)}',
      offset: Offset(tooltipX + 10, tooltipY + 96),
      fontSize: 11,
      color: const Color(0xFFD1D5DB),
    );

    _drawText(
      canvas: canvas,
      text: 'MA5   ${ma5 == null ? '-' : '₩ ${_formatPrice(ma5)}'}',
      offset: Offset(tooltipX + 10, tooltipY + 116),
      fontSize: 11,
      color: const Color(0xFFF59E0B),
      fontWeight: FontWeight.w800,
    );

    _drawText(
      canvas: canvas,
      text: 'MA20  ${ma20 == null ? '-' : '₩ ${_formatPrice(ma20)}'}',
      offset: Offset(tooltipX + 10, tooltipY + 133),
      fontSize: 11,
      color: const Color(0xFF8B5CF6),
      fontWeight: FontWeight.w800,
    );
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w600,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$month/$day';
  }

  @override
  bool shouldRepaint(covariant _CandleChartPainter oldDelegate) {
    return oldDelegate.candles != candles ||
        oldDelegate.hoverPosition != hoverPosition;
  }
}