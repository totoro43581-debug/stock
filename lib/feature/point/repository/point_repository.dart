import 'package:supabase_flutter/supabase_flutter.dart';

class PointRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> ensureUserPoints() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return;
    }

    await _client.rpc('ensure_user_points');
  }

  Future<Map<String, dynamic>?> fetchMyPoints() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _client
        .from('user_points')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return Map<String, dynamic>.from(response);
  }

  // 수정11차: returns table RPC 응답(List/Map)을 모두 처리
  Future<Map<String, dynamic>> fetchMyAssetSummary() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      return {
        'total_asset': 0,
        'cash_balance': 0,
      };
    }

    final response = await _client.rpc('get_my_asset_summary');

    if (response == null) {
      return {
        'total_asset': 0,
        'cash_balance': 0,
      };
    }

    if (response is List) {
      if (response.isEmpty) {
        return {
          'total_asset': 0,
          'cash_balance': 0,
        };
      }

      final firstRow = response.first;

      if (firstRow is Map) {
        return Map<String, dynamic>.from(firstRow);
      }
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return {
      'total_asset': 0,
      'cash_balance': 0,
    };
  }

  Future<Map<String, dynamic>> convertPointsToCash({
    required double points,
  }) async {
    final response = await _client.rpc(
      'convert_points_to_cash',
      params: {
        'p_amount': points,
      },
    );

    if (response is List) {
      if (response.isEmpty) {
        return {};
      }

      final firstRow = response.first;

      if (firstRow is Map) {
        return Map<String, dynamic>.from(firstRow);
      }
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return {};
  }

  Future<Map<String, dynamic>> earnPoints({
    required double points,
    required String reason,
  }) async {
    final response = await _client.rpc(
      'earn_points',
      params: {
        'p_points': points,
        'p_reason': reason,
      },
    );

    if (response is List) {
      if (response.isEmpty) {
        return {};
      }

      final firstRow = response.first;

      if (firstRow is Map) {
        return Map<String, dynamic>.from(firstRow);
      }
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    return {};
  }
}