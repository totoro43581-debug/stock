import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:stock/feature/stock/model/stock_trade_history_model.dart';

class StockTickLogSection extends StatefulWidget {
  final List<StockTradeHistoryModel> tradeHistoryItems;
  final ValueChanged<bool> onHoverChanged;

  const StockTickLogSection({
    super.key,
    required this.tradeHistoryItems,
    required this.onHoverChanged,
  });

  @override
  State<StockTickLogSection> createState() => _StockTickLogSectionState();
}

class _StockTickLogSectionState extends State<StockTickLogSection> {
  final ScrollController _scrollController = ScrollController();

  Timer? _flashTimer;

  bool _flashVisible = true;

  @override
  void initState() {
    super.initState();

    // 수정80차: dispose 이후 타이머가 setState를 호출하지 않도록 즉시 종료 처리
    _flashTimer = Timer.periodic(
      const Duration(milliseconds: 500),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        setState(() {
          _flashVisible = !_flashVisible;
        });
      },
    );
  }

  @override
  void dispose() {
    // 수정80차: 타이머를 먼저 확실히 종료
    _flashTimer?.cancel();
    _flashTimer = null;

    widget.onHoverChanged(false);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleLogs = [...widget.tradeHistoryItems]
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

        return bTime.compareTo(aTime);
      });

    final limitedLogs = visibleLogs.take(30).toList();

    return MouseRegion(
      onEnter: (_) => widget.onHoverChanged(true),
      onExit: (_) => widget.onHoverChanged(false),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (event) {
          if (event is! PointerScrollEvent) return;

          GestureBinding.instance.pointerSignalResolver.register(
            event,
                (PointerSignalEvent resolvedEvent) {
              if (resolvedEvent is! PointerScrollEvent) return;
              if (!_scrollController.hasClients) return;

              final position = _scrollController.position;

              final double nextOffset =
              (position.pixels + resolvedEvent.scrollDelta.dy).clamp(
                position.minScrollExtent,
                position.maxScrollExtent,
              );

              _scrollController.jumpTo(nextOffset);
            },
          );
        },
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(limitedLogs.length),
              const SizedBox(height: 10),
              _buildTableHeader(),
              const SizedBox(height: 8),
              Expanded(
                child: limitedLogs.isEmpty
                    ? _buildEmptyMessage()
                    : ListView.separated(
                  controller: _scrollController,
                  primary: false,
                  padding: EdgeInsets.zero,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: limitedLogs.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 6);
                  },
                  itemBuilder: (context, index) {
                    return _buildLogRow(
                      limitedLogs[index],
                      index,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        const Text(
          '최근 체결내역',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const Spacer(),
        Text(
          '최근 $count건',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '시간',
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Text(
              '구분',
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              '종목',
              style: _headerTextStyle,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '체결가',
              textAlign: TextAlign.right,
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 70,
            child: Text(
              '수량',
              textAlign: TextAlign.right,
              style: _headerTextStyle,
            ),
          ),
          SizedBox(width: 20),
          SizedBox(
            width: 120,
            child: Text(
              '체결금액',
              textAlign: TextAlign.right,
              style: _headerTextStyle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(
      StockTradeHistoryModel item,
      int index,
      ) {
    final bool isBuy = item.tradeType == 'buy';

    final Color color =
    isBuy ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    final String tradeTypeLabel = isBuy ? '매수체결' : '매도체결';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: index == 0 && _flashVisible
            ? color.withOpacity(0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              _formatDateTime(item.createdAt),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 78,
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  tradeTypeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    item.stockName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.stockCode,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '₩ ${_formatPrice(item.price)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 70,
            child: Text(
              '${_formatVolume(item.quantity)}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
              ),
            ),
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 120,
            child: Text(
              '₩ ${_formatPrice(item.totalAmount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMessage() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Text(
        '체결내역이 없습니다.',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return '$month-$day $hour:$minute:$second';
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatVolume(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  static const TextStyle _headerTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    color: Color(0xFF64748B),
  );
}