import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/wallet/model/wallet_model.dart';
import 'package:stock/feature/wallet/repository/wallet_repository.dart';
import 'package:stock/feature/wallet/widget/wallet_summary_section.dart';

class WalletSummaryLoaderSection extends StatefulWidget {
  const WalletSummaryLoaderSection({super.key});

  @override
  State<WalletSummaryLoaderSection> createState() =>
      _WalletSummaryLoaderSectionState();
}

class _WalletSummaryLoaderSectionState
    extends State<WalletSummaryLoaderSection> {
  final WalletRepository _walletRepository = WalletRepository();

  late Future<WalletModel> _walletFuture;

  @override
  void initState() {
    super.initState();
    _walletFuture = _loadWallet();
  }

  Future<WalletModel> _loadWallet() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인 사용자 정보가 없습니다.');
    }

    return _walletRepository.ensureWallet(user.id);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WalletModel>(
      future: _walletFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: const Color(0xFFE5E7EB),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '지갑 정보를 불러오지 못했습니다.\n${snapshot.error}',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        final wallet = snapshot.data!;

        return WalletSummarySection(wallet: wallet);
      },
    );
  }
}