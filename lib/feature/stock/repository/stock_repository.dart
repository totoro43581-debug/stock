import 'package:supabase_flutter/supabase_flutter.dart';

class StockRepository {
  final SupabaseClient _client = Supabase.instance.client;

  // 수정1차: 초기 지급금
  static const double _initialCashBalance = 2000000;

  // 수정88차: 현실형 가상 종목 정보 컬럼 포함
  Future<List<Map<String, dynamic>>> fetchActiveStocks() async {
    final response = await _client
        .from('stock_item')
        .select('''
          id,
          code,
          name,
          market,
          current_price,
          change_rate,
          virtual_buy_volume,
          virtual_sell_volume,
          trade_volume,
          trade_amount,
          company_description,
          stock_type,
          sector,
          market_cap_level,
          volatility_level,
          growth_score,
          stability_score,
          news_sensitivity,
          delisting_risk_score,
          listing_status
          ''')
        .eq('is_active', true)
        .order('market', ascending: true)
        .order('name', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // 수정103차: 활성 뉴스 지속 반영 RPC 호출 결과 확인
  Future<Map<String, dynamic>> applyActiveStockNewsEvents({
    bool force = false,
  }) async {
    print('수정103차 RPC 호출 시작 / force = $force');

    final response = await _client.rpc(
      'apply_active_stock_news_events',
      params: {'p_force': force},
    );

    print('수정103차 RPC 원본 응답 = $response');

    if (response == null) {
      final emptyResult = {
        'success': false,
        'message': '활성 뉴스 반영 결과가 없습니다.',
        'market_open': false,
        'force_applied': force,
        'news_count': 0,
        'stock_count': 0,
      };

      print('수정103차 RPC 빈 응답 처리 = $emptyResult');

      return emptyResult;
    }

    final result = Map<String, dynamic>.from(response as Map);

    print('수정103차 RPC 변환 결과 = $result');

    return result;
  }

  // 수정98차: 게임형 주식시장 상태 조회
  Future<Map<String, dynamic>> fetchStockMarketStatus({
    bool forceOpen = false,
  }) async {
    final response = await _client.rpc(
      'get_stock_market_status',
      params: {'p_force_open': forceOpen},
    );

    if (response == null) {
      return {
        'success': false,
        'is_open': false,
        'status_label': '상태미정',
        'remaining_minutes': 0,
        'next_status': '-',
        'description': '주식시장 상태를 불러오지 못했습니다.',
      };
    }

    return Map<String, dynamic>.from(response as Map);
  }

  // 수정95차: 최근 시장 뉴스 조회 - 지속 반영 상태 컬럼 포함
  Future<List<Map<String, dynamic>>> fetchRecentStockNewsEvents() async {
    final response = await _client
        .from('stock_news_events')
        .select('''
          id,
          news_code,
          title,
          content,
          body,
          news_type,
          source_type,
          source_label,
          impact_direction,
          importance_level,
          status,
          target_type,
          target_value,
          sentiment,
          min_impact_rate,
          max_impact_rate,
          volume_multiplier,
          is_applied,
          is_price_applied,
          is_visible,
          is_real_world_based,
          market_type,
          active_from,
          active_until,
          last_applied_at,
          total_impact_rate,
          remaining_impact_rate,
          apply_interval_minutes,
          applied_count,
          max_apply_count,
          created_at,
          applied_at,
          published_at
          ''')
        .eq('is_visible', true)
        .eq('market_type', 'stock')
        .order('created_at', ascending: false)
        .limit(8);

    return List<Map<String, dynamic>>.from(response);
  }

  // 수정1차: 사용자 지갑 보장
  Future<void> ensureUserWallet() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인 필요');
    }

    final response = await _client
        .from('user_wallet')
        .select('user_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response != null) {
      return;
    }

    await _client.from('user_wallet').insert({
      'user_id': user.id,
      'cash_balance': _initialCashBalance,
    });
  }

  // 수정1차: 사용자 지갑 조회
  Future<double> fetchUserWallet() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('로그인 필요');
    }

    await ensureUserWallet();

    final response = await _client
        .from('user_wallet')
        .select('cash_balance')
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return 0;
    }

    return (response['cash_balance'] as num).toDouble();
  }
}
