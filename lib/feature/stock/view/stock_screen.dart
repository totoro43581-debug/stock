import 'package:flutter/material.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  // 수정1차: 검색 컨트롤러
  final TextEditingController _searchController = TextEditingController();

  // 수정1차: 화면 상태값
  String _selectedMarketFilter = '전체';
  String _selectedSort = '등락률';
  bool _showOnlyOwned = false;

  // 수정1차: 보유 현금 / 총 자산 더미값
  double _cash = 8500000;
  double _investedAmount = 21500000;

  // 수정1차: 종목 더미 데이터
  late List<_StockItem> _stockItems;

  // 수정1차: 현재 선택 종목
  _StockItem? _selectedItem;

  @override
  void initState() {
    super.initState();

    _stockItems = [
      _StockItem(
        code: '005930',
        name: '삼성전자',
        market: '국내',
        currentPrice: 74200,
        changeRate: 1.82,
        changeAmount: 1320,
        ownedQuantity: 12,
        averagePrice: 70500,
        description: '반도체, 모바일, 가전 등 다양한 사업을 영위하는 대표 대형주입니다.',
      ),
      _StockItem(
        code: '000660',
        name: 'SK하이닉스',
        market: '국내',
        currentPrice: 189500,
        changeRate: -0.94,
        changeAmount: -1800,
        ownedQuantity: 4,
        averagePrice: 176000,
        description: '메모리 반도체 중심의 글로벌 반도체 기업입니다.',
      ),
      _StockItem(
        code: '035420',
        name: 'NAVER',
        market: '국내',
        currentPrice: 218000,
        changeRate: 2.40,
        changeAmount: 5100,
        ownedQuantity: 0,
        averagePrice: 0,
        description: '검색, 커머스, 콘텐츠, 클라우드 등을 운영하는 플랫폼 기업입니다.',
      ),
      _StockItem(
        code: 'AAPL',
        name: 'Apple',
        market: '해외',
        currentPrice: 268500,
        changeRate: 0.74,
        changeAmount: 1980,
        ownedQuantity: 3,
        averagePrice: 251200,
        description: '아이폰, 맥, 서비스 사업을 운영하는 글로벌 IT 기업입니다.',
      ),
      _StockItem(
        code: 'MSFT',
        name: 'Microsoft',
        market: '해외',
        currentPrice: 594000,
        changeRate: 1.21,
        changeAmount: 7100,
        ownedQuantity: 2,
        averagePrice: 548300,
        description: '클라우드, 오피스, AI, 게임 등 다양한 사업을 보유한 글로벌 기업입니다.',
      ),
      _StockItem(
        code: 'TSLA',
        name: 'Tesla',
        market: '해외',
        currentPrice: 251300,
        changeRate: -2.36,
        changeAmount: -6070,
        ownedQuantity: 1,
        averagePrice: 280000,
        description: '전기차 및 에너지 솔루션 중심의 글로벌 성장주입니다.',
      ),
    ];

    _selectedItem = _stockItems.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double get _totalStockValue {
    return _stockItems.fold(
      0,
          (sum, item) => sum + (item.currentPrice * item.ownedQuantity),
    );
  }

  double get _totalAsset {
    return _cash + _totalStockValue;
  }

  double get _profitAmount {
    return _stockItems.fold(
      0,
          (sum, item) => sum + item.profitAmount,
    );
  }

  double get _profitRate {
    if (_investedAmount <= 0) return 0;
    return (_profitAmount / _investedAmount) * 100;
  }

  List<_StockItem> get _filteredItems {
    List<_StockItem> result = List.of(_stockItems);

    // 수정1차: 시장 필터
    if (_selectedMarketFilter != '전체') {
      result = result
          .where((item) => item.market == _selectedMarketFilter)
          .toList();
    }

    // 수정1차: 보유 종목만 보기
    if (_showOnlyOwned) {
      result = result.where((item) => item.ownedQuantity > 0).toList();
    }

    // 수정1차: 검색
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(keyword) ||
            item.code.toLowerCase().contains(keyword);
      }).toList();
    }

    // 수정1차: 정렬
    switch (_selectedSort) {
      case '등락률':
        result.sort((a, b) => b.changeRate.compareTo(a.changeRate));
        break;
      case '현재가':
        result.sort((a, b) => b.currentPrice.compareTo(a.currentPrice));
        break;
      case '보유수량':
        result.sort((a, b) => b.ownedQuantity.compareTo(a.ownedQuantity));
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

  String _formatPrice(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
          (match) => ',',
    );
  }

  String _formatSignedPrice(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${_formatPrice(value)}';
  }

  String _formatSignedPercent(double value) {
    final prefix = value > 0 ? '+' : '';
    return '$prefix${value.toStringAsFixed(2)}%';
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;
    final selectedItem = _selectedItem;

    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFFF5F7FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1280;
          final isTablet = constraints.maxWidth >= 900;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 수정1차: 상단 제목 영역
                  _buildHeader(),

                  const SizedBox(height: 20),

                  // 수정1차: 자산 요약 카드 영역
                  _buildSummarySection(),

                  const SizedBox(height: 20),

                  // 수정1차: 검색/필터 영역
                  _buildFilterSection(),

                  const SizedBox(height: 20),

                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 7,
                          child: _buildStockListSection(filteredItems),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          flex: 5,
                          child: Column(
                            children: [
                              _buildDetailSection(selectedItem),
                              const SizedBox(height: 20),
                              _buildTradeSection(selectedItem),
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
                        _buildDetailSection(selectedItem),
                        const SizedBox(height: 20),
                        _buildTradeSection(selectedItem),
                      ],
                    )
                  else
                    Column(
                      children: [
                        _buildStockListSection(filteredItems),
                        const SizedBox(height: 16),
                        _buildDetailSection(selectedItem),
                        const SizedBox(height: 16),
                        _buildTradeSection(selectedItem),
                      ],
                    ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.show_chart_rounded,
              size: 28,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주식',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  '종목 조회, 보유 자산 확인, 매수/매도 체험을 한 화면에서 진행합니다.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        final isTablet = constraints.maxWidth >= 700;

        final cards = [
          _buildSummaryCard(
            title: '총 자산',
            value: '${_formatPrice(_totalAsset)}원',
            subValue: '현금 + 보유 주식 평가금액',
            valueColor: const Color(0xFF111827),
          ),
          _buildSummaryCard(
            title: '보유 현금',
            value: '${_formatPrice(_cash)}원',
            subValue: '즉시 매수 가능 금액',
            valueColor: const Color(0xFF111827),
          ),
          _buildSummaryCard(
            title: '주식 평가금액',
            value: '${_formatPrice(_totalStockValue)}원',
            subValue: '현재가 기준 보유 종목 합계',
            valueColor: const Color(0xFF111827),
          ),
          _buildSummaryCard(
            title: '평가손익',
            value: '${_formatSignedPrice(_profitAmount)}원',
            subValue: _formatSignedPercent(_profitRate),
            valueColor: _changeColor(_profitAmount),
          ),
        ];

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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
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

  Widget _buildFilterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
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
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
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
            items: const ['등락률', '현재가', '보유수량', '이름'],
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
            selectedColor: const Color(0xFFE0E7FF),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
            labelStyle: TextStyle(
              color: _showOnlyOwned
                  ? const Color(0xFF4338CA)
                  : const Color(0xFF374151),
              fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w600,
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 목록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 50),
              alignment: Alignment.center,
              child: const Text(
                '조건에 맞는 종목이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: const Row(
        children: [
          Expanded(
            flex: 28,
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
            flex: 18,
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
            flex: 18,
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
            flex: 18,
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
    final isSelected = _selectedItem?.code == item.code;
    final changeColor = _changeColor(item.changeRate);
    final profitColor = _changeColor(item.profitAmount);

    return InkWell(
      onTap: () {
        setState(() {
          _selectedItem = item;
        });
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFCBD5E1)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 28,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.market == '국내'
                          ? const Color(0xFF10B981)
                          : const Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${item.code} · ${item.market}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                '${_formatPrice(item.currentPrice)}원',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                _formatSignedPercent(item.changeRate),
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: changeColor,
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                '${item.ownedQuantity}주',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 18,
              child: Text(
                '${_formatSignedPrice(item.profitAmount)}원',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: profitColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(_StockItem? item) {
    if (item == null) {
      return _buildEmptyCard('선택된 종목이 없습니다.');
    }

    final changeColor = _changeColor(item.changeRate);
    final profitColor = _changeColor(item.profitAmount);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '종목 상세',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: item.market == '국내'
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.market,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: item.market == '국내'
                        ? const Color(0xFF047857)
                        : const Color(0xFF4338CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.code,
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
                  value: '${_formatPrice(item.currentPrice)}원',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '등락률',
                  value: _formatSignedPercent(item.changeRate),
                  valueColor: changeColor,
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
                  value: '${item.ownedQuantity}주',
                  valueColor: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDetailMetric(
                  title: '평가손익',
                  value: '${_formatSignedPrice(item.profitAmount)}원',
                  valueColor: profitColor,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '종목 설명',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
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

  Widget _buildTradeSection(_StockItem? item) {
    if (item == null) {
      return _buildEmptyCard('매매할 종목을 먼저 선택해주세요.');
    }

    final quantityController = TextEditingController(text: '1');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '매수 / 매도',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: quantityController,
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
                borderSide: const BorderSide(color: Color(0xFF6366F1)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주문 기준가: ${_formatPrice(item.currentPrice)}원',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '보유 현금: ${_formatPrice(_cash)}원',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '현재 보유수량: ${item.ownedQuantity}주',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} 매수 기능은 다음 단계에서 연결합니다.'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${item.name} 매도 기능은 다음 단계에서 연결합니다.'),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
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
  final double changeAmount;
  final int ownedQuantity;
  final double averagePrice;
  final String description;

  _StockItem({
    required this.code,
    required this.name,
    required this.market,
    required this.currentPrice,
    required this.changeRate,
    required this.changeAmount,
    required this.ownedQuantity,
    required this.averagePrice,
    required this.description,
  });

  double get stockValue => currentPrice * ownedQuantity;

  double get buyAmount => averagePrice * ownedQuantity;

  double get profitAmount => stockValue - buyAmount;
}