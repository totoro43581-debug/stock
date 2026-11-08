import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// The HTTP fixture uses Supabase's existing pinned transport dependency.
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:http/testing.dart';
import 'package:stock/feature/bank/view/widget/loan_catalog_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'loan_catalog_section_test.dart' as active;

class _CompletedFixture extends active.Fixture {
  bool completedFailure = false;
  bool receiptFailure = false;
  bool malformedCompleted = false;
  Completer<http.Response>? heldReceipt;
  http.Request? heldReceiptRequest;
  final completedRequests = <Map<String, dynamic>>[];
  final receiptRequests = <Map<String, dynamic>>[];

  static Map<String, dynamic> completed(
    String id,
    String name, {
    String updatedAt = '2026-10-31T13:54:00.446703+00:00',
  }) => {
    'id': id,
    'product_name': name,
    'loan_type': 'deposit_secured',
    'principal_amount': 50000,
    'principal_paid': 50000,
    'interest_paid': 197,
    'fee_paid': 0,
    'total_paid': 50197,
    'payment_count': 2,
    'last_payment_at': '2026-10-31T13:54:00Z',
    'updated_at': updatedAt,
  };

  static Map<String, dynamic> receipt(
    String id,
    num principal,
    num interest,
    String type,
    String at,
  ) => {
    'id': id,
    'payment_type': type,
    'principal_paid': principal,
    'interest_paid': interest,
    'fee_paid': 0,
    'total_paid': principal + interest,
    'created_at': at,
  };

  late Map<String, Map<String, dynamic>> completedPages = {
    'first': {
      'items': [completed('completed-one', '상환 완료된 예금담보대출')],
      'has_more': false,
      'next_cursor': null,
    },
  };

  late Map<String, Map<String, dynamic>> receiptPages = {
    'first': {
      'items': [
        receipt('final-receipt', 45000, 197, 'overdue', '2026-10-31T13:54:00Z'),
        receipt(
          'partial-receipt',
          5000,
          0,
          'partial_early',
          '2026-10-25T01:00:00Z',
        ),
      ],
      'has_more': false,
      'next_cursor': null,
    },
  };

  @override
  Future<http.Response> respond(http.Request request) async {
    final path = request.url.path;
    if (!path.endsWith('/rpc/get_my_repaid_loans') &&
        !path.endsWith('/rpc/get_my_loan_payment_history')) {
      return super.respond(request);
    }
    calls.add(path);
    final params = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
    final completedQuery = path.endsWith('/get_my_repaid_loans');
    (completedQuery ? completedRequests : receiptRequests).add(params);
    if (!completedQuery && heldReceipt != null) {
      heldReceiptRequest = request;
      return heldReceipt!.future;
    }
    final failed = completedQuery ? completedFailure : receiptFailure;
    final Object? result;
    if (failed) {
      result = {'code': 'XX000', 'message': 'unavailable'};
    } else if (completedQuery && malformedCompleted) {
      result = null;
    } else {
      final cursor = params['p_before_id']?.toString() ?? 'first';
      final pages = completedQuery ? completedPages : receiptPages;
      if (!pages.containsKey(cursor)) {
        throw StateError('Unexpected history cursor $cursor');
      }
      result = pages[cursor];
    }
    return http.Response(
      jsonEncode(result),
      failed ? 500 : 200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _CompletedFixture fixture;

  setUp(() async {
    fixture = _CompletedFixture();
    await Supabase.initialize(
      url: 'https://mock.invalid',
      anonKey: 'fixture',
      debug: false,
      httpClient: MockClient(fixture.respond),
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: false,
        detectSessionInUri: false,
        localStorage: const EmptyLocalStorage(),
        pkceAsyncStorage: active.MemoryPkce(),
      ),
    );
  });
  tearDown(() async {
    expect(fixture.mutations, isEmpty);
    await Supabase.instance.dispose();
  });

  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump();
    }
  }

  Future<void> mount(
    WidgetTester tester, {
    double width = 1440,
    double scale = 1,
  }) async {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: LoanCatalogSection(),
          ),
        ),
      ),
    );
    await drain(tester);
  }

  Finder completedTab() => find.byWidgetPredicate(
    (widget) =>
        widget is ChoiceChip &&
        widget.label is Text &&
        (widget.label as Text).data == '상환 완료',
  );

  Future<void> openCompleted(WidgetTester tester) async {
    await tester.ensureVisible(completedTab());
    await tester.tap(completedTab());
    await drain(tester);
  }

  Future<void> tapText(WidgetTester tester, String label) async {
    final finder = find.text(label).first;
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await drain(tester);
  }

  Future<void> disposeScreen(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());

  testWidgets(
    'completed history loads lazily and shows lifetime totals and real Korea completion time',
    (tester) async {
      await mount(tester);
      expect(fixture.completedRequests, isEmpty);
      await openCompleted(tester);
      expect(fixture.completedRequests, hasLength(1));
      expect(find.text('상환 완료된 예금담보대출'), findsOneWidget);
      // This is the whole contract, not only the final 45,197-won repayment.
      expect(find.text('50,197원'), findsWidgets);
      expect(find.text('50,000원'), findsWidgets);
      expect(find.text('197원'), findsWidgets);
      expect(find.textContaining('2026.10.31 오후 10:54:00'), findsWidgets);
      expect(find.widgetWithText(FilledButton, '상환·관리'), findsNothing);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'payment records are read only and preserve partial plus final receipts',
    (tester) async {
      await mount(tester);
      await openCompleted(tester);
      await tapText(tester, '상환 기록');
      await tester.pumpAndSettle();
      expect(fixture.receiptRequests.single['p_loan_id'], 'completed-one');
      final dialog = find.byType(Dialog);
      expect(dialog, findsOneWidget);
      expect(
        find.descendant(of: dialog, matching: find.text('45,197원')),
        findsWidgets,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('5,000원')),
        findsWidgets,
      );
      expect(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        findsNothing,
      );
      for (final label in ['정기상환', '일부상환', '전액상환']) {
        expect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(OutlinedButton, label),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialog,
            matching: find.widgetWithText(FilledButton, label),
          ),
          findsNothing,
        );
      }
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'completed list keyset pagination retains prior cards on failure and retries the same cursor',
    (tester) async {
      const stamp = '2026-10-31T13:54:00.446703+00:00';
      fixture.completedPages['first']!['has_more'] = true;
      fixture.completedPages['first']!['next_cursor'] = {
        'updated_at': stamp,
        'id': 'completed-one',
      };
      fixture.completedPages['completed-one'] = {
        'items': [_CompletedFixture.completed('completed-two', '이전 상환 완료 대출')],
        'has_more': false,
        'next_cursor': null,
      };
      await mount(tester);
      await openCompleted(tester);
      fixture.completedFailure = true;
      await tapText(tester, '상환 완료 내역 더 보기');
      expect(find.text('상환 완료된 예금담보대출'), findsOneWidget);
      expect(find.text('상환 완료된 대출이 없습니다.'), findsNothing);
      fixture.completedFailure = false;
      await tapText(tester, '상환 완료 내역 다시 조회');
      expect(find.text('상환 완료된 예금담보대출'), findsOneWidget);
      expect(find.text('이전 상환 완료 대출'), findsOneWidget);
      expect(fixture.completedRequests.last['p_before_id'], 'completed-one');
      expect(fixture.completedRequests.last['p_before_updated_at'], stamp);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'receipt pagination passes the selected loan and precise cursor without repeating the final payment',
    (tester) async {
      fixture.receiptPages['first']!['items'] = [
        _CompletedFixture.receipt(
          'final-receipt',
          45000,
          197,
          'overdue',
          '2026-10-31T13:54:00Z',
        ),
      ];
      fixture.receiptPages['first']!['has_more'] = true;
      fixture.receiptPages['first']!['next_cursor'] = {
        'created_at': '2026-10-31T13:54:00.123456+00:00',
        'id': 'final-receipt',
      };
      fixture.receiptPages['final-receipt'] = {
        'items': [
          _CompletedFixture.receipt(
            'partial-receipt',
            5000,
            0,
            'partial_early',
            '2026-10-25T01:00:00Z',
          ),
        ],
        'has_more': false,
        'next_cursor': null,
      };
      await mount(tester);
      await openCompleted(tester);
      await tapText(tester, '상환 기록');
      await tester.pumpAndSettle();
      await tapText(tester, '상환 기록 더 보기');
      expect(fixture.receiptRequests.last['p_loan_id'], 'completed-one');
      expect(fixture.receiptRequests.last['p_before_id'], 'final-receipt');
      expect(
        fixture.receiptRequests.last['p_before_created_at'],
        '2026-10-31T13:54:00.123456+00:00',
      );
      final dialog = find.byType(Dialog);
      expect(
        find.descendant(of: dialog, matching: find.text('45,197원')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('연체 상환')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('일부상환')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: dialog, matching: find.text('5,000원')),
        findsWidgets,
      );
      await disposeScreen(tester);
    },
  );

  for (final malformed in [false, true]) {
    testWidgets(
      'failed completed lookup ($malformed) is not represented as no repaid loans and can recover',
      (tester) async {
        fixture.completedFailure = !malformed;
        fixture.malformedCompleted = malformed;
        await mount(tester);
        await openCompleted(tester);
        expect(find.text('상환 완료된 대출이 없습니다.'), findsNothing);
        expect(find.text('상환 완료 내역 다시 조회'), findsOneWidget);
        fixture.completedFailure = false;
        fixture.malformedCompleted = false;
        await tapText(tester, '상환 완료 내역 다시 조회');
        expect(find.text('상환 완료된 예금담보대출'), findsOneWidget);
        await disposeScreen(tester);
      },
    );
  }

  testWidgets(
    'empty completed history is explicit, independent of active-loan failure',
    (tester) async {
      fixture.loanFailure = true;
      fixture.completedPages['first']!['items'] = [];
      await mount(tester);
      await openCompleted(tester);
      expect(find.text('상환 완료된 대출이 없습니다.'), findsOneWidget);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'legacy completed contracts without receipts do not fabricate zero totals or a completion timestamp',
    (tester) async {
      final loan = fixture.completedPages['first']!['items'] as List;
      (loan.first as Map<String, dynamic>).addAll(<String, dynamic>{
        'principal_paid': null,
        'interest_paid': null,
        'fee_paid': null,
        'total_paid': null,
        'last_payment_at': null,
        'payment_count': 0,
      });
      fixture.receiptPages['first']!['items'] = [];
      await mount(tester);
      await openCompleted(tester);
      expect(find.text('내역 확인 불가'), findsWidgets);
      expect(find.text('상환 시각 확인 불가'), findsOneWidget);
      expect(find.text('0원'), findsNothing);
      await tapText(tester, '상환 기록');
      await tester.pumpAndSettle();
      expect(find.text('표시할 상환 기록이 없습니다.'), findsOneWidget);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'receipt failure remains retryable without pretending there are no receipts',
    (tester) async {
      fixture.receiptFailure = true;
      await mount(tester);
      await openCompleted(tester);
      await tapText(tester, '상환 기록');
      await tester.pumpAndSettle();
      expect(find.text('표시할 상환 기록이 없습니다.'), findsNothing);
      expect(find.text('상환 기록 다시 조회'), findsOneWidget);
      fixture.receiptFailure = false;
      await tapText(tester, '상환 기록 다시 조회');
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('45,197원'),
        ),
        findsWidgets,
      );
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'completed cards and receipt dialog fit a 390px viewport at 130 percent text scale',
    (tester) async {
      await mount(tester, width: 390, scale: 1.3);
      await openCompleted(tester);
      expect(tester.takeException(), isNull);
      await tapText(tester, '상환 기록');
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );
  testWidgets(
    'a newly paid active contract refreshes the selected completed view after server polling',
    (tester) async {
      await mount(tester);
      await openCompleted(tester);
      expect(fixture.completedRequests, hasLength(1));
      fixture.credits = [];
      fixture.completedPages['first']!['items'] = [
        _CompletedFixture.completed('newly-paid', '방금 상환 완료된 신용대출'),
        _CompletedFixture.completed('completed-one', '상환 완료된 예금담보대출'),
      ];
      await tester.pump(const Duration(seconds: 60));
      await drain(tester);
      expect(fixture.completedRequests, hasLength(2));
      expect(find.text('방금 상환 완료된 신용대출'), findsOneWidget);
      expect(find.text('상환 완료된 예금담보대출'), findsOneWidget);
      await disposeScreen(tester);
    },
  );

  testWidgets(
    'closing the read-only dialog before a response arrives does not update disposed state',
    (tester) async {
      fixture.heldReceipt = Completer<http.Response>();
      await mount(tester);
      await openCompleted(tester);
      await tapText(tester, '상환 기록');
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.heldReceiptRequest, isNotNull);
      await tester.tap(find.byTooltip('닫기'));
      await tester.pumpAndSettle();
      fixture.heldReceipt!.complete(
        http.Response(
          jsonEncode(fixture.receiptPages['first']),
          200,
          request: fixture.heldReceiptRequest,
          headers: {'content-type': 'application/json'},
        ),
      );
      await drain(tester);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeScreen(tester);
    },
  );
}
