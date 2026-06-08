import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/coin/model/coin_holding_model.dart';
import 'package:stock/feature/coin/model/coin_item_model.dart';
import 'package:stock/feature/coin/model/coin_trade_history_model.dart';

class CoinBottomTabPanel extends StatelessWidget {
  final List<CoinHoldingModel> holdings;
  final List<CoinTradeHistoryModel> tradeHistories;
  final List<CoinItemModel> coins;
  final String selectedBottomTab;
  final NumberFormat moneyFormat;
  final String Function(double value) formatQuantity;
  final ValueChanged<String> onTabChanged;
  final ValueChanged<CoinItemModel> onCoinSelected;

  const CoinBottomTabPanel({
    super.key,
    required this.holdings,
    required this.tradeHistories,
    required this.coins,
    required this.selectedBottomTab,
    required this.moneyFormat,
    required this.formatQuantity,
    required this.onTabChanged,
    required this.onCoinSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: _exchangePanelDecoration(),
      child: Column(
        children: [
          Container(
            height: 46,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E7EB)),
              ),
            ),
            child: Row(
              children: [
                _buildBottomTabButton(
                  label: '보유 코인',
                  tab: 'holding',
                ),
                _buildBottomTabButton(
                  label: '거래내역',
                  tab: 'history',
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: Text(
                    selectedBottomTab == 'holding'
                        ? '${holdings.length}개'
                        : '최근 ${tradeHistories.length}건',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: selectedBottomTab == 'holding'
                ? _buildHoldingTable()
                : _buildTradeHistoryTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTabButton({
    required String label,
    required String tab,
  }) {
    final bool selected = selectedBottomTab == tab;

    return InkWell(
      onTap: () {
        onTabChanged(tab);
      },
      child: Container(
        width: 130,
        height: double.infinity,
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
            fontSize: 14,
            fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            color: selected ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildHoldingTable() {
    if (holdings.isEmpty) {
      return _buildEmptyTableBox('보유 중인 코인이 없습니다.');
    }

    return Column(
      children: [
        _buildHoldingHeaderRow(),
        Expanded(
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            itemCount: holdings.length,
            separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              return _buildHoldingRow(holdings[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHoldingHeaderRow() {
    return Container(
      height: 36,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Expanded(flex: 3, child: _TableHeaderText('코인')),
          Expanded(flex: 2, child: _TableHeaderText('수량', alignRight: true)),
          Expanded(flex: 2, child: _TableHeaderText('평균가', alignRight: true)),
          Expanded(flex: 2, child: _TableHeaderText('평가금액', alignRight: true)),
          Expanded(flex: 2, child: _TableHeaderText('손익', alignRight: true)),
        ],
      ),
    );
  }

  Widget _buildHoldingRow(CoinHoldingModel holding) {
    final CoinItemModel? coin = _findCoinByCode(holding.coinCode);
    final double currentPrice = coin?.currentPrice ?? holding.averagePrice;
    final double evaluationAmount = currentPrice * holding.quantity;
    final double profitAmount =
        evaluationAmount - (holding.averagePrice * holding.quantity);

    return InkWell(
      onTap: () {
        final CoinItemModel? selectedCoin = _findCoinByCode(holding.coinCode);

        if (selectedCoin == null) return;

        onCoinSelected(selectedCoin);
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                holding.coinName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _tableStrongTextStyle(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatQuantity(holding.quantity),
                textAlign: TextAlign.right,
                style: _tableTextStyle(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                moneyFormat.format(holding.averagePrice),
                textAlign: TextAlign.right,
                style: _tableTextStyle(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                moneyFormat.format(evaluationAmount),
                textAlign: TextAlign.right,
                style: _tableStrongTextStyle(),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                moneyFormat.format(profitAmount),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: profitAmount >= 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2563EB),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTradeHistoryTable() {
    if (tradeHistories.isEmpty) {
      return _buildEmptyTableBox('거래내역이 없습니다.');
    }

    return Column(
      children: [
        _buildTradeHistoryHeaderRow(),
        Expanded(
          child: ListView.separated(
            physics: const ClampingScrollPhysics(),
            itemCount: tradeHistories.length,
            separatorBuilder: (context, index) =>
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              return _buildTradeHistoryRow(tradeHistories[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTradeHistoryHeaderRow() {
    return Container(
      height: 36,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          SizedBox(width: 54, child: _TableHeaderText('구분')),
          Expanded(flex: 3, child: _TableHeaderText('코인')),
          Expanded(flex: 2, child: _TableHeaderText('수량', alignRight: true)),
          Expanded(flex: 2, child: _TableHeaderText('가격', alignRight: true)),
          Expanded(flex: 2, child: _TableHeaderText('금액', alignRight: true)),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryRow(CoinTradeHistoryModel history) {
    final bool isBuy = history.tradeType == 'buy';

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              isBuy ? '매수' : '매도',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isBuy
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              history.coinName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _tableStrongTextStyle(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              formatQuantity(history.quantity),
              textAlign: TextAlign.right,
              style: _tableTextStyle(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              moneyFormat.format(history.tradePrice),
              textAlign: TextAlign.right,
              style: _tableTextStyle(),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              moneyFormat.format(history.totalAmount),
              textAlign: TextAlign.right,
              style: _tableStrongTextStyle(),
            ),
          ),
        ],
      ),
    );
  }

  CoinItemModel? _findCoinByCode(String code) {
    for (final coin in coins) {
      if (coin.code == code) {
        return coin;
      }
    }

    return null;
  }

  Widget _buildEmptyTableBox(String text) {
    return Container(
      height: 96,
      alignment: Alignment.center,
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

  TextStyle _tableTextStyle() {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF374151),
    );
  }

  TextStyle _tableStrongTextStyle() {
    return const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w900,
      color: Color(0xFF111827),
    );
  }
}

const TextStyle _headerSmallStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w800,
  color: Color(0xFF6B7280),
);

class _TableHeaderText extends StatelessWidget {
  final String text;
  final bool alignRight;

  const _TableHeaderText(
      this.text, {
        this.alignRight = false,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.right : TextAlign.left,
      style: _headerSmallStyle,
    );
  }
}