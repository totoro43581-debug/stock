import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Mock the HTTP transport already provided by Supabase without changing app dependencies.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stock/feature/bank/view/widget/loan_catalog_section.dart';

class MemoryPkce extends GotrueAsyncStorage {
  final data = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => data[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    data.remove(key);
  }
}

class Fixture {
  bool loanFailure = false, offerFailure = false, epochFailure = false;
  final mutations = <String>[];
  final calls = <String>[];
  List<Map<String, dynamic>> credits = [
    credit('credit-one', '한빛은행 생활 신용대출', 45000),
  ];
  List<Map<String, dynamic>> secured = [
    {
      'id': 'secured-one',
      'product_name': '한빛은행 예금담보대출',
      'status': 'active',
      'outstanding_principal': 100000,
      'accrued_interest': 1200,
      'full_repayment_amount': 101200,
      'annual_rate': 4.2,
      'maturity_game_day': 180,
    },
  ];
  static Map<String, dynamic> credit(String id, String name, int principal) => {
    'id': id,
    'product_id': 'credit-product',
    'product_name': name,
    'status': 'overdue',
    'annual_rate': 7.5,
    'game_day': 157,
    'next_payment_game_day': 156,
    'maturity_game_day': 180,
    'outstanding_principal': principal,
    'interest_due': 900,
    'total_repayment_amount': principal + 900,
    'scheduled_payment': 10000,
  };
  Future<http.Response> respond(http.Request req) async {
    final path = req.url.path;
    calls.add(path);
    Object data;
    int status = 200;
    if (path.contains('/rpc/issue_') || path.contains('/rpc/repay_')) {
      mutations.add(path);
      throw StateError('Unexpected financial write');
    }
    if (path.endsWith('/rpc/get_my_loan_offers')) {
      data = offerFailure
          ? {'message': 'unavailable', 'code': 'XX000'}
          : [
              {
                'id': 'credit-product',
                'product_code': 'LOAN_CREDIT_BASIC',
                'product_name': '생활 신용대출 상품',
                'bank_name': '한빛은행',
                'is_active': true,
                'loan_type': 'credit',
                'annual_rate': 7.5,
                'min_amount': 1000,
                'max_amount': 100000,
                'min_term_game_days': 30,
                'max_term_game_days': 180,
                'indicative_limit': 100000,
                'precheck_status': 'precheck_possible',
              },
              {
                'id': 'secured-product',
                'product_code': 'LOAN_DEPOSIT_SECURED',
                'product_name': '예금담보대출 상품',
                'bank_name': '한빛은행',
                'is_active': true,
                'loan_type': 'deposit_secured',
                'annual_rate': 4.2,
                'min_amount': 1000,
                'max_amount': 10000000,
                'min_term_game_days': 10,
                'max_term_game_days': 365,
                'precheck_status': 'insufficient_collateral',
              },
            ];
      if (offerFailure) status = 500;
    } else if (path.endsWith('/rpc/get_my_loan_overview')) {
      data = {
        'outstanding_principal': [
          ...credits,
          ...secured,
        ].fold<num>(0, (sum, l) => sum + (l['outstanding_principal'] as num)),
        'active_loan_count': credits.length + secured.length,
        'credit_score': 590,
        'credit_grade': '주의',
        'income_verified': false,
      };
    } else if (path.endsWith('/rpc/get_my_credit_loans')) {
      data = loanFailure
          ? {'message': 'unavailable', 'code': 'XX000'}
          : credits;
      if (loanFailure) status = 500;
    } else if (path.endsWith('/rpc/get_my_deposit_secured_loans')) {
      data = secured;
    } else if (path.endsWith('/rpc/get_my_credit_loan_quote')) {
      data = {
        'min_amount': 1000,
        'approval_limit': 100000,
        'status': 'eligible',
      };
    } else if (path.endsWith('/game_clock_settings')) {
      data = epochFailure
          ? {'message': 'unavailable', 'code': '42501'}
          : {'virtual_epoch': '2025-12-31T15:00:00Z'};
      if (epochFailure) status = 403;
    } else {
      throw StateError('Unexpected endpoint $path');
    }
    return http.Response(
      jsonEncode(data),
      status,
      request: req,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Fixture fixture;
  setUp(() async {
    fixture = Fixture();
    await Supabase.initialize(
      url: 'https://mock.invalid',
      anonKey: 'fixture',
      debug: false,
      httpClient: MockClient(fixture.respond),
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: MemoryPkce(),
      ),
    );
  });
  tearDown(() async {
    expect(fixture.mutations, isEmpty);
    await Supabase.instance.dispose();
  });
  Future<void> drain(WidgetTester t) async {
    for (var i = 0; i < 50; i++) {
      await t.pump();
    }
  }

  final boundaryKey = GlobalKey();
  Future<void> mount(
    WidgetTester t, {
    double width = 1440,
    double height = 1400,
    double scale = 1,
  }) async {
    t.view.physicalSize = Size(width, height);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF3F5F9),
            body: RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: const Color(0xFFF3F5F9),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: LoanCatalogSection(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await drain(t);
  }

  testWidgets(
    'owned loans visible above products and independent of product filter',
    (t) async {
      await mount(t);
      expect(find.text('내 대출'), findsOneWidget);
      expect(find.text('한빛은행 생활 신용대출'), findsOneWidget);
      expect(find.text('한빛은행 예금담보대출'), findsOneWidget);
      expect(
        t.getTopLeft(find.text('내 대출')).dy,
        lessThan(t.getTopLeft(find.text('대출 상품')).dy),
      );
      await t.ensureVisible(find.text('예금담보'));
      await t.tap(find.text('예금담보'));
      await drain(t);
      expect(find.text('한빛은행 생활 신용대출'), findsOneWidget);
      expect(find.text('생활 신용대출 상품'), findsNothing);
      expect(find.text('상환·관리'), findsNWidgets(2));
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'credit management selects one contract and has no application form or quote request',
    (t) async {
      fixture.credits.add(Fixture.credit('credit-two', '다른 신용대출', 70000));
      await mount(t);
      final quotesBefore = fixture.calls
          .where((x) => x.endsWith('/get_my_credit_loan_quote'))
          .length;
      await t.tap(find.text('상환·관리').first);
      await t.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('한빛은행 생활 신용대출'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('다른 신용대출'),
        ),
        findsNothing,
      );
      expect(find.text('신규 신용대출 신청'), findsNothing);
      expect(
        fixture.calls
            .where((x) => x.endsWith('/get_my_credit_loan_quote'))
            .length,
        quotesBefore,
      );
      await t.ensureVisible(find.text('전액상환'));
      await t.tap(find.text('전액상환'));
      await t.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('45,900원'), findsWidgets);
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'collateral management works without product/deposit application queries',
    (t) async {
      await mount(t);
      await t.tap(find.text('상환·관리').last);
      await t.pumpAndSettle();
      expect(find.text('예금담보대출 상환'), findsOneWidget);
      expect(find.text('예금담보대출 신청'), findsNothing);
      expect(
        fixture.calls.any(
          (x) => x.endsWith('/loan_products') || x.endsWith('/bank_products'),
        ),
        isFalse,
      );
      await t.tap(find.text('전액상환'));
      await t.pumpAndSettle();
      expect(find.textContaining('101,200원'), findsWidgets);
      await t.tap(find.text('취소'));
      await t.pumpAndSettle();
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('empty and failed queries are distinct and retry recovers', (
    t,
  ) async {
    fixture.loanFailure = true;
    await mount(t);
    expect(find.text('내 대출 다시 조회'), findsOneWidget);
    expect(find.text('이용 중인 대출이 없습니다.'), findsNothing);
    fixture.loanFailure = false;
    fixture.credits = [];
    fixture.secured = [];
    await t.tap(find.text('내 대출 다시 조회'));
    await drain(t);
    expect(find.text('이용 중인 대출이 없습니다.'), findsOneWidget);
    await t.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'catalog failure does not hide existing loans; missing epoch does not invent dates',
    (t) async {
      fixture.offerFailure = true;
      fixture.epochFailure = true;
      await mount(t);
      expect(find.text('한빛은행 생활 신용대출'), findsOneWidget);
      expect(find.text('상환·관리'), findsNWidgets(2));
      expect(find.text('날짜 확인 불가'), findsNWidgets(3));
      await t.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final width in [390.0, 768.0, 1440.0]) {
    testWidgets('readable layout $width at 130 percent text scale', (t) async {
      fixture.secured = [];
      await mount(t, width: width, height: 1400, scale: 1.3);
      expect(t.takeException(), isNull);
      final text = t.widget<Text>(find.text('잔여 원금').first);
      expect(text.style!.fontSize, greaterThanOrEqualTo(14));
      await t.pumpWidget(const SizedBox.shrink());
    });
  }
}
