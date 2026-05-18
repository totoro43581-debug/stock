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
        final aTime = a.createdAt ?? DateTime.now();
        final bTime = b.createdAt ?? DateTime.now();

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
        child: Container(
          height: 240,
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '실시간 체결',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: visibleLogs.isEmpty
                    ? const Center(
                  child: Text(
                    '체결 로그가 없습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                )
                    : ListView.separated(
                  controller: _scrollController,
                  primary: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: limitedLogs.length,
                  separatorBuilder: (_, __) {
                    return const Divider(
                      height: 1,
                      color: Color(0xFFF1F5F9),
                    );
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

  Widget _buildLogRow(
      StockTradeHistoryModel item,
      int index,
      ) {
    final bool isBuy = item.tradeType == 'buy';

    final Color color =
    isBuy ? const Color(0xFFDC2626) : const Color(0xFF2563EB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: index == 0 && _flashVisible
          ? BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Text(
              _formatTime(item.createdAt ?? DateTime.now()),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF94A3B8),
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              isBuy ? '매수체결' : '매도체결',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.stockName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              '₩ ${_formatPrice(item.price)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '${_formatVolume(item.quantity)}주',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              '₩ ${_formatPrice(item.totalAmount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: const Color(0xFFE5E7EB),
      ),
    );
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
}