import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Use Supabase's existing pinned transport for an isolated HTTP fixture.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/view/bank_screen.dart';

class _Pkce extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const uid = '10000000-0000-0000-0000-000000000001';
  late List<Map<String, dynamic>> transactions;
  late List<Uri> historyRequests;
  var failHistory = false;
  Map<String, dynamic> row(
    String id,
    String reason,
    String title, {
    String account = 'bank',
    String type = 'out',
    num amount = 45197,
  }) => {
    'id': id,
    'user_id': uid,
    'account_type': account,
    'reason': reason,
    'type': type,
    'amount': amount,
    'balance_after': 880345,
    'title': title,
    'memo': '원금 45000원 / 이자 197원',
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };
  setUp(() async {
    failHistory = false;
    historyRequests = [];
    transactions = [
      row('automatic', 'loan_repayment', '예금담보대출 자동상환'),
      row(
        'manual',
        'credit_loan_repayment',
        '신용대출 상환',
        type: 'withdraw',
        amount: 1000,
      ),
      row(
        'issue',
        'credit_loan_disbursement',
        '신용대출 실행',
        type: 'deposit',
        amount: 50000,
      ),
      row('future', 'future_bank_reason', '새 은행 거래', amount: 100),
      row(
        'transfer',
        'asset_transfer',
        '계좌 이체 출금',
        account: 'stock',
        amount: 10000,
      ),
      row(
        'excluded',
        'stock_buy',
        '은행과 무관한 주식 체결',
        account: 'stock',
        amount: 20000,
      ),
    ];
    await Supabase.initialize(
      url: 'https://mock.invalid',
      anonKey: 'fixture',
      debug: false,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: _Pkce(),
      ),
      httpClient: MockClient((req) async {
        final path = req.url.path;
        Object data;
        if (path.endsWith('/rpc/get_game_clock')) {
          data = {
            'game_datetime': '2026-06-06T00:00:00Z',
            'game_seconds_per_real_second': 6,
            'bank_products_time_model': 'virtual',
          };
        } else if (path.endsWith('/game_clock_settings')) {
          data = {
            'real_epoch': '2026-10-05T00:00:00Z',
            'virtual_epoch': '2025-12-31T15:00:00Z',
            'game_seconds_per_real_second': 6,
          };
        } else if (path.endsWith('/rpc/ensure_user_asset_accounts')) {
          data = {};
        } else if (path.endsWith('/user_asset_accounts')) {
          data = [
            {
              'id': 'bank',
              'user_id': uid,
              'account_type': 'bank',
              'cash_balance': 880345,
              'is_active': true,
            },
          ];
        } else if (path.endsWith('/bank_products') ||
            path.endsWith('/user_bank_accounts')) {
          data = [];
        } else if (path.endsWith('/asset_account_transactions')) {
          historyRequests.add(req.url);
          if (failHistory) {
            return http.Response(
              jsonEncode({'code': 'XX000', 'message': 'unavailable'}),
              500,
              request: req,
              headers: {'content-type': 'application/json'},
            );
          }
          // Evaluate the query predicates so the old whitelist implementation fails this test.
          final orFilter = req.url.queryParameters['or'];
          final reasonFilter = req.url.queryParameters['reason'] ?? '';
          data = transactions
              .where(
                (r) => orFilter != null
                    ? (r['account_type'] == 'bank' &&
                              orFilter.contains('account_type.eq.bank')) ||
                          orFilter.contains(r['reason'] as String)
                    : reasonFilter.contains(r['reason'] as String),
              )
              .toList();
        } else {
          throw StateError('Unexpected request / financial write: $path');
        }
        return http.Response(
          jsonEncode(data),
          200,
          request: req,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    String encode(Object data) =>
        base64Url.encode(utf8.encode(jsonEncode(data))).replaceAll('=', '');
    final exp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
    final token =
        '${encode({'alg': 'HS256', 'typ': 'JWT'})}.${encode({'sub': uid, 'exp': exp})}.fixture';
    await Supabase.instance.client.auth.recoverSession(
      jsonEncode({
        'access_token': token,
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': uid,
          'aud': 'authenticated',
          'role': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          'created_at': '2026-01-01T00:00:00Z',
        },
      }),
    );
  });
  tearDown(() async {
    await Supabase.instance.dispose();
  });
  Future<void> drain(WidgetTester t) async {
    for (var i = 0; i < 50; i++) {
      await t.pump();
    }
  }

  Future<void> mount(
    WidgetTester t, {
    double width = 1440,
    double textScale = 1,
  }) async {
    t.view.physicalSize = Size(width, 1800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: BankScreen()),
      ),
    );
    await drain(t);
    await t.ensureVisible(find.text('거래내역').first);
    await t.tap(find.text('거래내역').first);
    await drain(t);
  }

  testWidgets(
    'real bank history includes automatic/manual loans, all bank reasons and legacy transfers',
    (t) async {
      await mount(t);
      expect(find.text('예금담보대출 자동상환'), findsOneWidget);
      expect(find.text('-45,197원'), findsOneWidget);
      expect(find.text('신용대출 상환'), findsOneWidget);
      expect(find.text('신용대출 실행'), findsOneWidget);
      expect(find.text('새 은행 거래'), findsOneWidget);
      expect(find.text('계좌 이체 출금'), findsOneWidget);
      expect(find.text('은행과 무관한 주식 체결'), findsNothing);
      expect(find.text('loan_repayment'), findsNothing);
      expect(find.text('credit_loan_repayment'), findsNothing);
      for (final uri in historyRequests) {
        expect(uri.queryParameters['user_id'], 'eq.$uid');
        expect(uri.queryParameters['or'], contains('account_type.eq.bank'));
        expect(uri.queryParameters['order'], startsWith('created_at.desc'));
        expect(uri.queryParameters['limit'], '300');
      }
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'entering history and the next minute refresh externally created repayments',
    (t) async {
      transactions = [];
      t.view.physicalSize = const Size(1440, 1800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: BankScreen())));
      await drain(t);
      transactions = [row('first', 'loan_repayment', '예금담보대출 자동상환')];
      await t.ensureVisible(find.text('거래내역').first);
      await t.tap(find.text('거래내역').first);
      await drain(t);
      expect(find.text('예금담보대출 자동상환'), findsOneWidget);
      transactions = [
        row('new', 'credit_loan_repayment', '새 정기상환 내역'),
        ...transactions,
      ];
      await t.pump(const Duration(seconds: 60));
      await drain(t);
      expect(find.text('새 정기상환 내역'), findsOneWidget);
      expect(find.text('예금담보대출 자동상환'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'history refresh failure preserves existing rows with a retry message',
    (t) async {
      await mount(t);
      failHistory = true;
      await t.pump(const Duration(seconds: 60));
      await drain(t);
      expect(find.text('예금담보대출 자동상환'), findsOneWidget);
      expect(find.text('최신 거래내역을 불러오지 못했습니다. 다시 조회해 주세요.'), findsOneWidget);
      failHistory = false;
      await t.ensureVisible(find.text('거래내역 다시 조회'));
      await t.tap(find.text('거래내역 다시 조회'));
      await drain(t);
      expect(find.text('최신 거래내역을 불러오지 못했습니다. 다시 조회해 주세요.'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('compact history keeps loan debit visible without overflow', (
    t,
  ) async {
    await mount(t, width: 390, textScale: 1.3);
    expect(find.text('예금담보대출 자동상환'), findsOneWidget);
    expect(find.text('-45,197원'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
