import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  // 수정2차: 검색 / 주문 입력 컨트롤러
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController =
  TextEditingController(text: '1');

  // 수정2차: 필터 상태
  String _selectedMarketFilter = '전체';
  String _selectedSort = '등락률';
  bool _showOnlyOwned = false;

  // 수정2차: 실제 보유 데이터는 아직 미연결이므로 비어있는 상태로 시작
  final List<_StockItem> _marketItems = [];
  final List<_HoldingItem> _holdingItems = [];
  final List<_TradeHistoryItem> _tradeHistoryItems = [];

  _StockItem? _selectedMarketItem;

  SupabaseClient get _supabase => Supabase.instance.client;

  Session? get _session => _supabase.auth.currentSession;
  User? get _user => _supabase.auth.currentUser;

  bool get _isLoggedIn => _session != null && _user != null;

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  // 수정2차: 실제 자산 데이터 미연결 상태이므로 0으로 계산
  double get _cash => 0;
  double get _totalStockValue => 0;
  double get _totalAsset => 0;
  double get _totalProfitAmount => 0;
  double get _totalProfitRate => 0;

  List<_StockItem> get _filteredItems {
    List<_StockItem> result = List.of(_marketItems);

    if (_selectedMarketFilter != '전체') {
      result = result
          .where((item) => item.market == _selectedMarketFilter)
          .toList();
    }

    final String keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(keyword) ||
            item.code.toLowerCase().contains(keyword);
      }).toList();
    }

    if (_showOnlyOwned) {
      result = result.where((item) {
        return _holdingItems.any((holding) => holding.code == item.code);
      }).toList();
    }

    switch (_selectedSort) {
      case '등락률':
        result.sort((a, b) => b.changeRate.compareTo(a.changeRate));
        break;
      case '현재가':
        result.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case '이름':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    return result;
  }

  Color _changeColor(double value) {
    if (value > 0) return const Color(0xFFDC2626);
    if (value < 0) return const Color(0xFF2563EB);
    return const Color(0xFF6B7280);
  }

  String _formatPrice(num value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatSignedPrice(num value) {
    final String prefix = value > 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatSignedPercent(double value) {
    final String prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleBuy() {
    if (!_isLoggedIn) {
      _showSnackBar('로그인 후 이용 가능합니다.');
      return;
    }

    _showSnackBar('실제 매수 기능은 보유 현금 / 종목 테이블 연결 후 구현합니다.');
  }

  void _handleSell() {
    if (!_isLoggedIn) {
      _showSnackBar('로그인 후 이용 가능합니다.');
      return;
    }

    _showSnackBar('실제 매도 기능은 보유 종목 / 거래내역 테이블 연결 후 구현합니다.');
  }

  @override
  Widget build(BuildContext context) {
    final List<_StockItem> filteredItems = _filteredItems;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF3F5F9),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isWide = constraints.maxWidth >= 1280;
          final bool isTablet = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildSummarySection(),
                    const SizedBox(height: 20),
                    _buildLoginNoticeSection(),
                    const SizedBox(height: 20),
                    _buildFilterSection(),
                    const SizedBox(height: 20),
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: Column(
                              children: [
                                _buildStockListSection(filteredItems),
                                const SizedBox(height: 20),
                                _buildTradeHistorySection(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildDetailSection(),
                                const SizedBox(height: 20),
                                _buildTradeSection(),
                                const SizedBox(height: 20),
                                _buildChartPlaceholderSection(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else if (isTablet)
                      Column(
                        children: [
                          _buildStockListSection(filteredItems),
                          const SizedBox(height: 20),
                          _buildDetailSection(),
                          const SizedBox(height: 20),
                          _buildTradeSection(),
                          const SizedBox(height: 20),
                          _buildChartPlaceholderSection(),
                          const SizedBox(height: 20),
                          _buildTradeHistorySection(),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildStockListSection(filteredItems),
                          const SizedBox(height: 16),
                          _buildDetailSection(),
                          const SizedBox(height: 16),
                          _buildTradeSection(),
                          const SizedBox(height: 16),
                          _buildChartPlaceholderSection(),
                          const SizedBox(height: 16),
                          _buildTradeHistorySection(),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF1E293B),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주식',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  '로그인 상태와 실제 보유 데이터 기준으로 자산, 보유종목, 거래내역이 표시됩니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFCBD5E1),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(0.12),
              ),
            ),
            child: Text(
              _isLoggedIn ? '로그인 상태' : '비로그인 상태',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final List<Widget> cards = [
      _buildSummaryCard(
        title: '총 자산',
        value: '₩ ${_formatPrice(_totalAsset)}',
        subValue: _isLoggedIn ? '실제 자산 연결 전' : '비로그인 상태',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '보유 현금',
        value: '₩ ${_formatPrice(_cash)}',
        subValue: _isLoggedIn ? '지갑 데이터 연결 전' : '비로그인 상태',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '주식 평가금',
        value: '₩ ${_formatPrice(_totalStockValue)}',
        subValue: _isLoggedIn ? '보유 종목 없음' : '비로그인 상태',
        valueColor: const Color(0xFF111827),
      ),
      _buildSummaryCard(
        title: '총 손익',
        value: '${_formatSignedPrice(_totalProfitAmount)}원',
        subValue: _formatSignedPercent(_totalProfitRate),
        valueColor: _changeColor(_totalProfitAmount),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 1100;
        final bool isTablet = constraints.maxWidth >= 700;

        if (isWide) {
          return Row(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                Expanded(child: cards[i]),
                if (i != cards.length - 1) const SizedBox(width: 16),
              ],
            ],
          );
        }

        if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              cards[i],
              if (i != cards.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subValue,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subValue,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginNoticeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isLoggedIn ? Colors.white : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isLoggedIn
              ? const Color(0xFFE5E7EB)
              : const Color(0xFFFCD34D),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isLoggedIn ? Icons.info_outline_rounded : Icons.lock_outline_rounded,
            color: _isLoggedIn
                ? const Color(0xFF2563EB)
                : const Color(0xFFB45309),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isLoggedIn
                  ? '현재 계정 기준 실제 자산/보유종목/거래내역 테이블 연결이 아직 안 되어 있어 0으로 표시됩니다.'
                  : '비로그인 상태입니다. 로그인하지 않았으므로 자산, 보유종목, 거래내역은 표시되지 않습니다.',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '종목명 / 종목코드 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF2563EB)),
                ),
              ),
            ),
          ),
          _buildDropdownBox(
            value: _selectedMarketFilter,
            items: const ['전체', '국내', '해외'],
            onChanged: (value) {
              setState(() {
                _selectedMarketFilter = value!;
              });
            },
          ),
          _buildDropdownBox(
            value: _selectedSort,
            items: const ['등락률', '현재가', '이름'],
            onChanged: (value) {
              setState(() {
                _selectedSort = value!;
              });
            },
          ),
          FilterChip(
            label: const Text('보유 종목만'),
            selected: _showOnlyOwned,
            onSelected: (value) {
              setState(() {
                _showOnlyOwned = value;
              });
            },
            selectedColor: const Color(0xFFDBEAFE),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            labelStyle: TextStyle(
              color: _showOnlyOwned
                  ? const Color(0xFF1D4ED8)
                  : const Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownBox({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          items: items
              .map(
                (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item),
            ),
          )
              .toList(),
          onChanged: onChanged,
          borderRadius: BorderRadius.circular(14),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ),
    );
  }

  Widget _buildStockListSection(List<_StockItem> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 목록',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 60),
              alignment: Alignment.center,
              child: Text(
                _isLoggedIn
                    ? '종목 마스터(stock_item) 연결 전입니다.'
                    : '비로그인 상태이며, 현재 종목 데이터도 아직 연결되지 않았습니다.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            Column(
              children: [
                _buildListHeader(),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                for (int i = 0; i < items.length; i++) ...[
                  _buildListRow(items[i]),
                  if (i != items.length - 1)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildListHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Expanded(
            flex: 30,
            child: Text(
              '종목',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              '현재가',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              '등락률',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 16,
            child: Text(
              '보유수량',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            flex: 18,
            child: Text(
              '평가손익',
              textAlign: TextAlign.right,
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

  Widget _buildListRow(_StockItem item) {
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMarketItem = item;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Row(
          children: [
            Expanded(
              flex: 30,
              child: Text(
                item.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 20,
              child: Text(
                '₩ ${_formatPrice(item.currentPrice)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                _formatSignedPercent(item.changeRate),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _changeColor(item.changeRate),
                ),
              ),
            ),
            const Expanded(
              flex: 16,
              child: Text(
                '0주',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const Expanded(
              flex: 18,
              child: Text(
                '0원',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection() {
    if (_selectedMarketItem == null) {
      return _buildEmptyCard('선택된 종목이 없습니다. 현재는 종목 데이터도 미연결 상태입니다.');
    }

    final item = _selectedMarketItem!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '선택 종목 상세',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            item.name,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${item.code} · ${item.market}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '현재가',
                  value: '₩ ${_formatPrice(item.currentPrice)}',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '등락률',
                  value: _formatSignedPercent(item.changeRate),
                  valueColor: _changeColor(item.changeRate),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '보유수량',
                  value: '0주',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '평균단가',
                  value: '-',
                  valueColor: const Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildDetailMetric(
                  title: '평가금액',
                  value: '₩ 0',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '평가손익',
                  value: '0원',
                  valueColor: const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              item.description.isEmpty
                  ? '종목 설명 데이터가 없습니다.'
                  : item.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailMetric({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매수 / 매도',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _quantityController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '수량',
              hintText: '주문 수량 입력',
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _isLoggedIn
                  ? '실제 매수/매도는 user_wallet, stock_holding, stock_trade_history 연결 후 활성화됩니다.'
                  : '비로그인 상태에서는 주문할 수 없습니다.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.6,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoggedIn ? _handleBuy : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '매수',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoggedIn ? _handleSell : null,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '매도',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartPlaceholderSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '차트 영역',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
            ),
            child: const Center(
              child: Text(
                '차트는 종목 시세 데이터 연결 후 표시됩니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '최근 체결내역',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (_tradeHistoryItems.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36),
              alignment: Alignment.center,
              child: Text(
                _isLoggedIn
                    ? '거래내역이 없습니다.'
                    : '비로그인 상태에서는 거래내역이 표시되지 않습니다.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            )
          else
            Column(
              children: _tradeHistoryItems
                  .map((item) => _buildTradeHistoryRow(item))
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTradeHistoryRow(_TradeHistoryItem item) {
    final bool isBuy = item.tradeType == '매수';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isBuy
                  ? const Color(0xFFECFDF5)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.tradeType,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isBuy
                    ? const Color(0xFF047857)
                    : const Color(0xFFB91C1C),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              item.stockName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Text(
            '${item.quantity}주',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 18),
          Text(
            '₩ ${_formatPrice(item.price)}',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: 110,
            child: Text(
              item.dateText,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _StockItem {
  final String code;
  final String name;
  final String market;
  final double currentPrice;
  final double changeRate;
  final String description;

  _StockItem({
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.description,
  });
}

class _HoldingItem {
  final String code;
  final int quantity;
  final double averagePrice;

  _HoldingItem({
    required this.code,
    required this.quantity,
    required this.averagePrice,
  });
}

class _TradeHistoryItem {
  final String stockName;
  final String tradeType;
  final int quantity;
  final double price;
  final String dateText;

  _TradeHistoryItem({
    required this.stockName,
    required this.tradeType,
    required this.quantity,
    required this.price,
    required this.dateText,
  });
}