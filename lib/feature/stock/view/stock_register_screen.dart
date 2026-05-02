import 'package:flutter/material.dart';
import 'package:stock/feature/stock/repository/stock_admin_repository.dart';

class StockRegisterScreen extends StatefulWidget {
  const StockRegisterScreen({super.key});

  @override
  State<StockRegisterScreen> createState() => _StockRegisterScreenState();
}

class _StockRegisterScreenState extends State<StockRegisterScreen> {
  final StockAdminRepository _repository = StockAdminRepository();

  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _selectedMarket = 'KOSPI';
  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _marketItems = [
    'KOSPI',
    'KOSDAQ',
    'NASDAQ',
    'NYSE',
    'AMEX',
  ];

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _saveStock() async {
    final String code = _codeController.text.trim();
    final String name = _nameController.text.trim();
    final int? price = int.tryParse(_priceController.text.trim());

    if (code.isEmpty) {
      _showMessage('종목코드를 입력해주세요.');
      return;
    }

    if (name.isEmpty) {
      _showMessage('종목명을 입력해주세요.');
      return;
    }

    if (price == null || price <= 0) {
      _showMessage('현재가는 1 이상 숫자로 입력해주세요.');
      return;
    }

    if (_isSaving) return;

    try {
      setState(() {
        _isSaving = true;
      });

      await _repository.createStockItem(
        code: code,
        name: name,
        market: _selectedMarket,
        currentPrice: price,
        changeRate: 0,
        isActive: _isActive,
      );

      if (!mounted) return;

      _codeController.clear();
      _nameController.clear();
      _priceController.clear();

      _showMessage('종목이 등록되었습니다.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('종목 등록 실패: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '종목 등록',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Supabase stock_item 테이블에 신규 종목을 등록합니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 24),

                  TextField(
                    controller: _codeController,
                    decoration: _inputDecoration(
                      '종목코드',
                      '예: 005930 / AAPL',
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _nameController,
                    decoration: _inputDecoration(
                      '종목명',
                      '예: 삼성전자 / 애플',
                    ),
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _selectedMarket,
                    items: _marketItems
                        .map(
                          (market) => DropdownMenuItem<String>(
                        value: market,
                        child: Text(market),
                      ),
                    )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedMarket = value;
                      });
                    },
                    decoration: _inputDecoration(
                      '시장',
                      '시장 선택',
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(
                      '현재가',
                      '예: 72000',
                    ),
                  ),
                  const SizedBox(height: 14),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      '활성화',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    subtitle: const Text(
                      '활성화된 종목만 주식 화면에 표시됩니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveStock,
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _isSaving ? '등록 중' : '종목 등록',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}