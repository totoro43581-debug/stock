import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/point/repository/point_repository.dart';

class MyAssetCardSection extends StatefulWidget {
  final User? user;

  const MyAssetCardSection({
    super.key,
    required this.user,
  });

  @override
  State<MyAssetCardSection> createState() => _MyAssetCardSectionState();
}

class _MyAssetCardSectionState extends State<MyAssetCardSection> {
  bool _isSigningOut = false;
  bool _isLoadingAsset = false;

  double _totalAsset = 0;
  double _cashBalance = 0;

  final NumberFormat _numberFormat = NumberFormat('#,###');

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadAssetData();
  }

  Future<void> _loadAssetData() async {
    final User? user = widget.user;

    if (user == null) {
      return;
    }

    setState(() {
      _isLoadingAsset = true;
    });

    try {
      final summary = await PointRepository().fetchMyAssetSummary();

      if (!mounted) return;

      final double cashBalance = _toDouble(summary['cash_balance']);
      final double totalAsset = _toDouble(summary['total_asset']);

      setState(() {
        _cashBalance = cashBalance;
        _totalAsset = totalAsset > 0 ? totalAsset : cashBalance;
      });
    } catch (e) {
      if (!mounted) return;

      debugPrint('자산 요약 조회 실패: $e');

      setState(() {
        _totalAsset = 0;
        _cashBalance = 0;
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoadingAsset = false;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃되었습니다.')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그아웃 중 오류가 발생했습니다.')),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String email = widget.user?.email ?? '-';
    final String displayName =
        widget.user?.userMetadata?['user_name']?.toString() ?? '사용자';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '내 자산',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$displayName님',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _buildCompactAssetRow(
            title: '총 자산',
            value: _isLoadingAsset
                ? '-'
                : '₩ ${_numberFormat.format(_totalAsset)}',
            valueColor: const Color(0xFF111827),
          ),
          const SizedBox(height: 8),
          _buildCompactAssetRow(
            title: '보유 현금',
            value: _isLoadingAsset
                ? '-'
                : '₩ ${_numberFormat.format(_cashBalance)}',
            valueColor: const Color(0xFF1D4ED8),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: _isSigningOut ? null : _signOut,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF111827),
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSigningOut
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2.0),
              )
                  : const Text(
                '로그아웃',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactAssetRow({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Container(
      width: double.infinity,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}