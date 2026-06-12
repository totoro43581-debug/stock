import 'dart:math';

import 'package:flutter/material.dart';

import 'package:stock/feature/coin/model/coin_item_model.dart';
import 'package:stock/feature/coin/model/coin_price_history_model.dart';

class CoinChartPanel extends StatefulWidget {
  final CoinItemModel? coin;
  final List<CoinPriceHistoryModel> priceHistories;

  const CoinChartPanel({
    super.key,
    required this.coin,
    required this.priceHistories,
  });

  @override
  State<CoinChartPanel> createState() => _CoinChartPanelState();
}

class _CoinChartPanelState extends State<CoinChartPanel> {
  String _selectedPeriod = '기본차트';

  @override
  Widget build(BuildContext context) {
    final bool isUp = (widget.coin?.changeRate ?? 0) >= 0;
    final List<_CandleData> candles = _buildCandles(widget.priceHistories);

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
              child: widget.coin == null
                  ? _buildEmptyText('선택된 코인이 없습니다.')
                  : candles.length < 2
                  ? _buildEmptyText('차트 이력이 부족합니다.')
                  : CustomPaint(
                painter: _CoinCandleChartPainter(
                  candles: candles,
                  isUp: isUp,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          _buildChartBottomToolbar(
            candleCount: candles.length,
            totalCount: widget.priceHistories.length,
          ),
        ],
      ),
    );
  }

  List<_CandleData> _buildCandles(List<CoinPriceHistoryModel> histories) {
    if (histories.length < 2) {
      return [];
    }

    final List<CoinPriceHistoryModel> sortedHistories = [...histories]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    switch (_selectedPeriod) {
      case '1분':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.minute,
          bucketSize: 1,
          fallbackLimit: 80,
        );

      case '5분':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.minute,
          bucketSize: 5,
          fallbackLimit: 80,
        );

      case '30분':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.minute,
          bucketSize: 30,
          fallbackLimit: 80,
        );

      case '1시간':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.hour,
          bucketSize: 1,
          fallbackLimit: 80,
        );

      case '일':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.day,
          bucketSize: 1,
          fallbackLimit: 80,
        );

      case '월':
        return _buildTimeBucketCandles(
          histories: sortedHistories,
          bucketType: _CandleBucketType.month,
          bucketSize: 1,
          fallbackLimit: 80,
        );

      case '기본차트':
      default:
        return _buildRawCandles(
          histories: _takeLatest(sortedHistories, 80),
        );
    }
  }

  List<CoinPriceHistoryModel> _takeLatest(
      List<CoinPriceHistoryModel> histories,
      int count,
      ) {
    if (histories.length <= count) {
      return histories;
    }

    return histories.sublist(histories.length - count);
  }

  List<_CandleData> _buildRawCandles({
    required List<CoinPriceHistoryModel> histories,
  }) {
    if (histories.length < 2) {
      return [];
    }

    final List<_CandleData> result = [];

    for (int i = 0; i < histories.length; i++) {
      final CoinPriceHistoryModel current = histories[i];
      final CoinPriceHistoryModel previous = i == 0 ? current : histories[i - 1];

      final double open = previous.price;
      final double close = current.price;
      final double wickRange = max(
        close.abs() * 0.0015,
        (close - open).abs() * 0.35,
      );

      result.add(
        _CandleData(
          open: open,
          high: max(open, close) + wickRange,
          low: max(1, min(open, close) - wickRange),
          close: close,
          volume: current.tradeVolume,
          createdAt: current.createdAt,
        ),
      );
    }

    return result;
  }

  List<_CandleData> _buildTimeBucketCandles({
    required List<CoinPriceHistoryModel> histories,
    required _CandleBucketType bucketType,
    required int bucketSize,
    required int fallbackLimit,
  }) {
    if (histories.length < 2) {
      return [];
    }

    final List<CoinPriceHistoryModel> limitedHistories =
    _takeLatest(histories, 240);

    final Map<DateTime, List<CoinPriceHistoryModel>> grouped = {};

    for (final history in limitedHistories) {
      final DateTime bucketTime = _bucketStartTime(
        history.createdAt,
        bucketType,
        bucketSize,
      );

      grouped.putIfAbsent(bucketTime, () => []);
      grouped[bucketTime]!.add(history);
    }

    final List<DateTime> bucketKeys = grouped.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    final List<_CandleData> candles = [];

    for (final key in bucketKeys) {
      final List<CoinPriceHistoryModel> group = grouped[key]!;

      if (group.isEmpty) continue;

      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final double open = group.first.price;
      final double close = group.last.price;

      double high = group.first.price;
      double low = group.first.price;
      double volume = 0;

      for (final history in group) {
        if (history.price > high) high = history.price;
        if (history.price < low) low = history.price;
        volume += history.tradeVolume;
      }

      candles.add(
        _CandleData(
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
          createdAt: key,
        ),
      );
    }

    final List<_CandleData> visibleCandles = _takeLatestCandles(candles, 80);

    if (visibleCandles.length >= 2) {
      return visibleCandles;
    }

    // 현재 데이터가 아직 같은 시간 구간에만 몰린 경우 차트가 1봉만 나오므로,
    // 개발 초반에는 원본 흐름으로 fallback 처리한다.
    return _buildRawCandles(
      histories: _takeLatest(histories, fallbackLimit),
    );
  }

  List<_CandleData> _takeLatestCandles(
      List<_CandleData> candles,
      int count,
      ) {
    if (candles.length <= count) {
      return candles;
    }

    return candles.sublist(candles.length - count);
  }

  DateTime _bucketStartTime(
      DateTime dateTime,
      _CandleBucketType bucketType,
      int bucketSize,
      ) {
    final DateTime local = dateTime.toLocal();

    switch (bucketType) {
      case _CandleBucketType.minute:
        final int minute = (local.minute ~/ bucketSize) * bucketSize;
        return DateTime(
          local.year,
          local.month,
          local.day,
          local.hour,
          minute,
        );

      case _CandleBucketType.hour:
        final int hour = (local.hour ~/ bucketSize) * bucketSize;
        return DateTime(
          local.year,
          local.month,
          local.day,
          hour,
        );

      case _CandleBucketType.day:
        return DateTime(
          local.year,
          local.month,
          local.day,
        );

      case _CandleBucketType.month:
        return DateTime(
          local.year,
          local.month,
        );
    }
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
            _buildChartPeriodButton('1분'),
            _buildChartPeriodButton('5분'),
            _buildChartPeriodButton('30분'),
            _buildChartPeriodButton('1시간'),
            _buildChartPeriodButton('일'),
            _buildChartPeriodButton('월'),
            const SizedBox(width: 14),
            _buildChartPeriodButton('기본차트'),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBottomToolbar({
    required int candleCount,
    required int totalCount,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: Row(
        children: [
          Text(
            _selectedPeriod,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '$candleCount봉 / 원본 $totalCount개',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          const Text(
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

  Widget _buildChartPeriodButton(String label) {
    final bool selected = _selectedPeriod == label;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPeriod = label;
        });
      },
      child: Container(
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

class _CoinCandleChartPainter extends CustomPainter {
  final List<_CandleData> candles;
  final bool isUp;

  const _CoinCandleChartPainter({
    required this.candles,
    required this.isUp,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.length < 2) return;

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.8;

    final Paint upStrokePaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Paint downStrokePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Paint upFillPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..style = PaintingStyle.fill;

    final Paint downFillPaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.fill;

    final Paint volumeUpPaint = Paint()
      ..color = const Color(0x55DC2626)
      ..style = PaintingStyle.fill;

    final Paint volumeDownPaint = Paint()
      ..color = const Color(0x552563EB)
      ..style = PaintingStyle.fill;

    for (int i = 1; i <= 5; i++) {
      final double y = size.height * i / 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (int i = 1; i <= 8; i++) {
      final double x = size.width * i / 9;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    final List<_CandleData> visibleCandles =
    candles.length > 80 ? candles.sublist(candles.length - 80) : candles;

    final double candleAreaHeight = size.height * 0.76;
    final double volumeTop = size.height * 0.80;
    final double volumeHeight = size.height * 0.18;

    double minPrice = visibleCandles.first.low;
    double maxPrice = visibleCandles.first.high;
    double maxVolume = 0;

    for (final candle in visibleCandles) {
      if (candle.low < minPrice) minPrice = candle.low;
      if (candle.high > maxPrice) maxPrice = candle.high;
      if (candle.volume > maxVolume) maxVolume = candle.volume;
    }

    if (maxPrice <= minPrice) {
      maxPrice = minPrice + 1;
    }

    if (maxVolume <= 0) {
      maxVolume = 1;
    }

    final double priceRange = maxPrice - minPrice;
    final double gap = size.width / visibleCandles.length;
    final double candleWidth = min(9, max(3.5, gap * 0.45));

    double priceToY(double price) {
      final double ratio = (price - minPrice) / priceRange;
      return candleAreaHeight - (ratio * (candleAreaHeight - 28)) + 14;
    }

    for (int i = 0; i < visibleCandles.length; i++) {
      final _CandleData candle = visibleCandles[i];

      final bool up = candle.close >= candle.open;

      final double x = gap * i + gap * 0.5;

      final double highY = priceToY(candle.high).clamp(10, candleAreaHeight);
      final double lowY = priceToY(candle.low).clamp(10, candleAreaHeight);
      final double openY = priceToY(candle.open).clamp(10, candleAreaHeight);
      final double closeY = priceToY(candle.close).clamp(10, candleAreaHeight);

      final Paint strokePaint = up ? upStrokePaint : downStrokePaint;
      final Paint fillPaint = up ? upFillPaint : downFillPaint;
      final Paint volumePaint = up ? volumeUpPaint : volumeDownPaint;

      canvas.drawLine(
        Offset(x, highY),
        Offset(x, lowY),
        strokePaint,
      );

      final Rect bodyRect = Rect.fromLTRB(
        x - candleWidth / 2,
        min(openY, closeY),
        x + candleWidth / 2,
        max(openY, closeY),
      );

      final Rect fixedBodyRect = bodyRect.height < 2
          ? Rect.fromCenter(
        center: bodyRect.center,
        width: candleWidth,
        height: 2,
      )
          : bodyRect;

      canvas.drawRect(fixedBodyRect, fillPaint);

      final double volumeRatio = (candle.volume / maxVolume).clamp(0.05, 1);
      final Rect volumeRect = Rect.fromLTWH(
        x - candleWidth / 2,
        volumeTop + volumeHeight * (1 - volumeRatio),
        candleWidth,
        volumeHeight * volumeRatio,
      );

      canvas.drawRect(volumeRect, volumePaint);
    }

    final Paint currentPricePaint = Paint()
      ..color = isUp ? const Color(0xFFDC2626) : const Color(0xFF2563EB)
      ..strokeWidth = 1;

    final double currentY = priceToY(visibleCandles.last.close).clamp(
      10,
      candleAreaHeight,
    );

    canvas.drawLine(
      Offset(0, currentY),
      Offset(size.width, currentY),
      currentPricePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CoinCandleChartPainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.isUp != isUp;
  }
}

class _CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime createdAt;

  const _CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.createdAt,
  });
}

enum _CandleBucketType {
  minute,
  hour,
  day,
  month,
}