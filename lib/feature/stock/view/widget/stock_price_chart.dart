import 'package:flutter/material.dart';
import 'package:stock/feature/stock/model/stock_price_model.dart';

class StockPriceChart extends StatelessWidget {
  final List<StockPriceModel> prices;

  const StockPriceChart({
    super.key,
    required this.prices,
  });

  @override
  Widget build(BuildContext context) {
    if (prices.isEmpty) {
      return Container(
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xffe5e7eb)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          '차트 데이터가 없습니다.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xff6b7280),
          ),
        ),
      );
    }

    return Container(
      height: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe5e7eb)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: CustomPaint(
        painter: _StockPriceChartPainter(prices),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _StockPriceChartPainter extends CustomPainter {
  final List<StockPriceModel> prices;

  _StockPriceChartPainter(this.prices);

  @override
  void paint(Canvas canvas, Size size) {
    if (prices.length < 2) return;

    final chartPadding = 36.0;
    final chartWidth = size.width - chartPadding * 2;
    final chartHeight = size.height - chartPadding * 2;

    final priceValues = prices.map((e) => e.price).toList();
    final minPrice = priceValues.reduce((a, b) => a < b ? a : b);
    final maxPrice = priceValues.reduce((a, b) => a > b ? a : b);

    final priceGap = maxPrice - minPrice == 0 ? 1 : maxPrice - minPrice;

    final axisPaint = Paint()
      ..color = const Color(0xffd1d5db)
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = const Color(0xff2563eb)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = const Color(0xff2563eb)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = const Color(0xfff3f4f6)
      ..strokeWidth = 1;

    // 수정1차: 가로 보조선
    for (int i = 0; i <= 4; i++) {
      final y = chartPadding + chartHeight / 4 * i;
      canvas.drawLine(
        Offset(chartPadding, y),
        Offset(chartPadding + chartWidth, y),
        gridPaint,
      );
    }

    // 수정1차: 세로축 / 가로축
    canvas.drawLine(
      Offset(chartPadding, chartPadding),
      Offset(chartPadding, chartPadding + chartHeight),
      axisPaint,
    );

    canvas.drawLine(
      Offset(chartPadding, chartPadding + chartHeight),
      Offset(chartPadding + chartWidth, chartPadding + chartHeight),
      axisPaint,
    );

    final path = Path();

    for (int i = 0; i < prices.length; i++) {
      final x = chartPadding + (chartWidth / (prices.length - 1)) * i;
      final normalized = (prices[i].price - minPrice) / priceGap;
      final y = chartPadding + chartHeight - normalized * chartHeight;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
    }

    canvas.drawPath(path, linePaint);

    // 수정1차: 최고가 / 최저가 텍스트
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: '최고 ${maxPrice.toStringAsFixed(0)}',
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xff374151),
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(chartPadding + 4, chartPadding - 20));

    textPainter.text = TextSpan(
      text: '최저 ${minPrice.toStringAsFixed(0)}',
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xff374151),
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(chartPadding + 4, chartPadding + chartHeight + 6),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}