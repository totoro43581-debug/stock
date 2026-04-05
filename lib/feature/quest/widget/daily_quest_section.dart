import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/quest/model/daily_quest_model.dart';
import 'package:stock/feature/quest/repository/daily_quest_repository.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';

class DailyQuestSection extends StatefulWidget {
  const DailyQuestSection({super.key});

  @override
  State<DailyQuestSection> createState() => _DailyQuestSectionState();
}

class _DailyQuestSectionState extends State<DailyQuestSection> {
  final DailyQuestRepository _questRepository = DailyQuestRepository();
  final WalletRepository _walletRepository = WalletRepository();

  bool _isLoading = true;
  bool _isClaiming = false;

  WalletModel? _wallet;
  List<DailyQuestModel> _quests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;

      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다.');
      }

      await _questRepository.ensureTodayQuests();

      final wallet = await _walletRepository.ensureWallet(currentUserId);
      final quests = await _questRepository.fetchTodayQuests();

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _quests = quests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('일일 퀘스트 로딩 실패: $e'),
        ),
      );
    }
  }

  Future<void> _claimQuest(String questCode) async {
    if (_isClaiming) return;

    setState(() {
      _isClaiming = true;
    });

    try {
      final result = await _questRepository.claimQuest(questCode);

      await _load();

      if (!mounted) return;

      final rewardAmount = (result['rewardAmount'] as num?)?.toInt() ?? 0;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보상 수령 완료: +${_formatWon(rewardAmount)}원'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('보상 수령 실패: $e'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isClaiming = false;
      });
    }
  }

  String _formatWon(int value) {
    final source = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < source.length; i++) {
      buffer.write(source[i]);
      final remain = source.length - i - 1;
      if (remain > 0 && remain % 3 == 0) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  Widget _buildStatusButton(DailyQuestModel quest) {
    if (quest.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '수령 완료',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
      );
    }

    if (quest.isCompleted) {
      return ElevatedButton(
        onPressed: _isClaiming ? null : () => _claimQuest(quest.code),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF111827),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          '보상 받기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '진행 중',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF92400E),
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '일일 퀘스트',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '현재 wallet 잔액: ${_wallet == null ? '-' : '${_formatWon(_wallet!.cashBalance)}원'}',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 20),
          ..._quests.map(
                (quest) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          quest.description,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '보상 ${_formatWon(quest.rewardAmount)}원',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildStatusButton(quest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}