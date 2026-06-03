import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:stock/feature/asset_account/repository/asset_account_repository.dart';
import 'package:stock/feature/asset_account/view/widget/asset_transaction_list_widget.dart';

class StockAssetAccountScreen extends StatefulWidget {
  const StockAssetAccountScreen({super.key});

  @override
  State<StockAssetAccountScreen> createState() =>
      _StockAssetAccountScreenState();
}

class _StockAssetAccountScreenState extends State<StockAssetAccountScreen> {
  final AssetAccountRepository _assetAccountRepository =
  AssetAccountRepository();

  final NumberFormat _moneyFormat = NumberFormat('#,###');

  bool _isLoading = true;

  double _stockCashBalance = 0;
  List<Map<String, dynamic>> _stockTransactions = [];

  @override
  void initState() {
    super.initState();
    _loadStockAssetAccountData();
  }

  Future<void> _loadStockAssetAccountData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _assetAccountRepository.ensureUserAssetAccounts();

      final results = await Future.wait([
        _assetAccountRepository.fetchAccountCashBalance(
          accountType: 'stock',
        ),
        _assetAccountRepository.fetchAssetAccountTransactions(
          reasons: const [
            'asset_to_stock',
            'stock_to_asset',
            'stock_buy',
            'stock_sell',
          ],
          limit: 20,
        ),
      ]);

      if (!mounted) return;

      setState(() {
        _stockCashBalance = results[0] as double;
        _stockTransactions = results[1] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCompact = MediaQuery.of(context).size.width < 760;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: RefreshIndicator(
        onRefresh: _loadStockAssetAccountData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isCompact ? 10 : 16),
          child: Column(
            children: [
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                _buildAssetSummaryCard(isCompact: isCompact),
                const SizedBox(height: 14),
                _buildAccountFlowCard(isCompact: isCompact),
                const SizedBox(height: 14),
                AssetTransactionListWidget(
                  title: '주식 계좌 거래내역',
                  transactions: _stockTransactions,
                ),
                const SizedBox(height: 14),
                _buildDepositSavingCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetSummaryCard({
    required bool isCompact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주식 자산계좌',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '주식 투자용 현금, 매수/매도 거래내역을 관리합니다.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 18),
          if (isCompact)
            Column(
              children: [
                _buildSummaryBox(
                  title: '주식 투자 현금',
                  amount: '${_formatMoney(_stockCashBalance)}원',
                  isStrong: true,
                ),
                const SizedBox(height: 10),
                _buildSummaryBox(
                  title: '최근 거래내역',
                  amount: '${_stockTransactions.length}건',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildSummaryBox(
                    title: '주식 투자 현금',
                    amount: '${_formatMoney(_stockCashBalance)}원',
                    isStrong: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryBox(
                    title: '최근 거래내역',
                    amount: '${_stockTransactions.length}건',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryBox(
                    title: '주식 평가금',
                    amount: '추후 연결',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSummaryBox(
                    title: '총 주식 자산',
                    amount: '추후 연결',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String amount,
    bool isStrong = false,
  }) {
    return Container(
      height: 86,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isStrong ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isStrong ? const Color(0xFF111827) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isStrong ? Colors.white70 : const Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isStrong ? Colors.white : const Color(0xFF111827),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountFlowCard({
    required bool isCompact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '주식 계좌 흐름',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          if (isCompact)
            Column(
              children: [
                _buildFlowButton(
                  title: '주식 매수',
                  subtitle: '주식 투자 현금 감소',
                ),
                const SizedBox(height: 10),
                _buildFlowButton(
                  title: '주식 매도',
                  subtitle: '주식 투자 현금 증가',
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildFlowButton(
                    title: '주식 매수',
                    subtitle: '주식 투자 현금 감소',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFlowButton(
                    title: '주식 매도',
                    subtitle: '주식 투자 현금 증가',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFlowButton(
                    title: '미체결 주문',
                    subtitle: '예약 주문 관리',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildFlowButton(
                    title: '체결 내역',
                    subtitle: '매수/매도 기록',
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFlowButton({
    required String title,
    required String subtitle,
  }) {
    return Container(
      height: 74,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositSavingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '안내',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              '예금/적금은 은행 탭에서 별도로 관리합니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );
  }

  String _formatMoney(double value) {
    return _moneyFormat.format(value.floor());
  }
}