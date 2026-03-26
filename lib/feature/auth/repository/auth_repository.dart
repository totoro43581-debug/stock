import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  final SupabaseClient _client = Supabase.instance.client;

  // 수정1차: login_id로 profiles 조회 후 email로 로그인
  Future<void> signInWithLoginId({
    required String loginId,
    required String password,
  }) async {
    final profile = await _client
        .from('profiles')
        .select('email')
        .eq('login_id', loginId)
        .maybeSingle();

    if (profile == null) {
      throw Exception('존재하지 않는 아이디입니다.');
    }

    final email = profile['email'] as String?;
    if (email == null || email.isEmpty) {
      throw Exception('해당 아이디에 연결된 이메일이 없습니다.');
    }

    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // 수정1차: 회원가입 + profiles 저장
  Future<void> signUp({
    required String loginId,
    required String password,
    required String userName,
    required String phone,
    required String email,
    required bool agreeTerms,
    required bool agreePrivacy,
    required bool agreeMarketing,
  }) async {
    final duplicatedLoginId = await _client
        .from('profiles')
        .select('id')
        .eq('login_id', loginId)
        .maybeSingle();

    if (duplicatedLoginId != null) {
      throw Exception('이미 사용 중인 아이디입니다.');
    }

    final duplicatedEmail = await _client
        .from('profiles')
        .select('id')
        .eq('email', email)
        .maybeSingle();

    if (duplicatedEmail != null) {
      throw Exception('이미 사용 중인 이메일입니다.');
    }

    final authResponse = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = authResponse.user;

    if (user == null) {
      throw Exception('회원가입은 요청되었지만 사용자 생성에 실패했습니다.');
    }

    await _client.from('profiles').insert({
      'id': user.id,
      'login_id': loginId,
      'user_name': userName,
      'phone': phone,
      'email': email,
      'role': 'user',
      'agree_terms': agreeTerms,
      'agree_privacy': agreePrivacy,
      'agree_marketing': agreeMarketing,
    });
  }

  // 수정1차: 로그아웃
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // 수정1차: 현재 로그인 사용자
  User? get currentUser => _client.auth.currentUser;
}