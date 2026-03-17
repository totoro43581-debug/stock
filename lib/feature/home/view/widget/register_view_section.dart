import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterViewSection extends StatefulWidget {
  final VoidCallback onCloseRegisterView;

  const RegisterViewSection({
    super.key,
    required this.onCloseRegisterView,
  });

  @override
  State<RegisterViewSection> createState() => _RegisterViewSectionState();
}

class _RegisterViewSectionState extends State<RegisterViewSection> {
  final TextEditingController _registerIdController = TextEditingController();
  final TextEditingController _registerPasswordController =
  TextEditingController();
  final TextEditingController _registerPasswordConfirmController =
  TextEditingController();
  final TextEditingController _registerUserNameController =
  TextEditingController();
  final TextEditingController _registerPhoneController =
  TextEditingController();
  final TextEditingController _registerEmailIdController =
  TextEditingController();
  final TextEditingController _registerEmailDomainDirectController =
  TextEditingController();

  bool _isLoading = false;

  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  String? _selectedEmailDomain;

  SupabaseClient get _supabase => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _registerPasswordController.addListener(_refreshUi);
    _registerPasswordConfirmController.addListener(_refreshUi);
    _registerEmailIdController.addListener(_refreshUi);
    _registerEmailDomainDirectController.addListener(_refreshUi);
    _registerIdController.addListener(_refreshUi);
    _registerUserNameController.addListener(_refreshUi);
    _registerPhoneController.addListener(_refreshUi);
  }

  @override
  void dispose() {
    _registerIdController.dispose();
    _registerPasswordController.dispose();
    _registerPasswordConfirmController.dispose();
    _registerUserNameController.dispose();
    _registerPhoneController.dispose();
    _registerEmailIdController.dispose();
    _registerEmailDomainDirectController.dispose();
    super.dispose();
  }

  void _refreshUi() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _signUp() async {
    final String loginId = _registerIdController.text.trim();
    final String password = _registerPasswordController.text.trim();
    final String passwordConfirm =
    _registerPasswordConfirmController.text.trim();
    final String userName = _registerUserNameController.text.trim();
    final String phone = _registerPhoneController.text.trim();
    final String email = _buildRegisterEmail();

    if (loginId.isEmpty) {
      _showMessage('ID를 입력해 주세요.');
      return;
    }

    if (!_isValidLoginId(loginId)) {
      _showMessage('ID는 4~20자 영문, 숫자, 밑줄(_)만 사용할 수 있습니다.');
      return;
    }

    if (!_isValidPassword(password)) {
      _showMessage(
        '비밀번호는 최소 8자리, 소문자와 숫자를 포함하고 연속 숫자를 사용할 수 없습니다.',
      );
      return;
    }

    if (password != passwordConfirm) {
      _showMessage('비밀번호와 비밀번호 확인이 일치하지 않습니다.');
      return;
    }

    if (userName.isEmpty) {
      _showMessage('사용자명을 입력해 주세요.');
      return;
    }

    if (phone.isEmpty) {
      _showMessage('연락처를 입력해 주세요.');
      return;
    }

    if (!_isValidPhone(phone)) {
      _showMessage('연락처 형식이 올바르지 않습니다.');
      return;
    }

    if (_registerEmailIdController.text.trim().isEmpty) {
      _showMessage('이메일 아이디를 입력해 주세요.');
      return;
    }

    if (_selectedEmailDomain == null) {
      _showMessage('이메일 도메인을 선택해 주세요.');
      return;
    }

    if (email.isEmpty) {
      _showMessage('이메일을 입력해 주세요.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('이메일 형식이 올바르지 않습니다.');
      return;
    }

    if (!_agreeTerms) {
      _showMessage('이용약관 동의가 필요합니다.');
      return;
    }

    if (!_agreePrivacy) {
      _showMessage('개인정보 수집 및 이용 동의가 필요합니다.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'login_id': loginId,
          'user_name': userName,
          'phone': phone,
          'agree_terms': _agreeTerms,
          'agree_privacy': _agreePrivacy,
          'agree_marketing': _agreeMarketing,
        },
      );

      final User? user = response.user;

      if (user == null) {
        if (!mounted) return;
        _showMessage('회원가입 응답은 받았지만 사용자 정보가 없습니다.');
        return;
      }

      try {
        await _supabase.from('profile').upsert({
          'id': user.id,
          'email': email,
          'login_id': loginId,
          'user_name': userName,
          'phone': phone,
          'agree_terms': _agreeTerms,
          'agree_privacy': _agreePrivacy,
          'agree_marketing': _agreeMarketing,
        });
      } on PostgrestException catch (e) {
        if (!mounted) return;
        _showMessage('Auth 가입은 완료되었지만 profile 저장 실패: ${e.message}');
        return;
      } catch (e) {
        if (!mounted) return;
        _showMessage('Auth 가입은 완료되었지만 profile 저장 중 오류: $e');
        return;
      }

      if (!mounted) return;

      _showMessage('회원가입이 완료되었습니다.');
      _clearRegisterForm();
      widget.onCloseRegisterView();
    } on AuthException catch (e) {
      if (!mounted) return;
      _showMessage('회원가입 실패: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      _showMessage('회원가입 중 오류: $e');
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _clearRegisterForm() {
    _registerIdController.clear();
    _registerPasswordController.clear();
    _registerPasswordConfirmController.clear();
    _registerUserNameController.clear();
    _registerPhoneController.clear();
    _registerEmailIdController.clear();
    _registerEmailDomainDirectController.clear();

    _selectedEmailDomain = null;
    _agreeTerms = false;
    _agreePrivacy = false;
    _agreeMarketing = false;
  }

  void _onPhoneChanged(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    String formatted = digits;

    if (digits.length <= 3) {
      formatted = digits;
    } else if (digits.length <= 7) {
      formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length <= 11) {
      formatted =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else {
      formatted =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }

    _registerPhoneController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  String _buildRegisterEmail() {
    final String emailId = _registerEmailIdController.text.trim();

    if (_selectedEmailDomain == null) {
      return '';
    }

    final String domain = _selectedEmailDomain == 'direct'
        ? _registerEmailDomainDirectController.text.trim()
        : _selectedEmailDomain!;

    if (emailId.isEmpty || domain.isEmpty) {
      return '';
    }

    return '$emailId@$domain';
  }

  bool _isValidLoginId(String value) {
    return RegExp(r'^[a-zA-Z0-9_]{4,20}$').hasMatch(value);
  }

  bool _isValidPassword(String value) {
    final bool hasMinLength = value.length >= 8;
    final bool hasLowercase = RegExp(r'[a-z]').hasMatch(value);
    final bool hasNumber = RegExp(r'[0-9]').hasMatch(value);
    final bool hasSequentialNumber = RegExp(
      r'012|123|234|345|456|567|678|789|890|098|987|876|765|654|543|432|321|210',
    ).hasMatch(value);

    return hasMinLength &&
        hasLowercase &&
        hasNumber &&
        !hasSequentialNumber;
  }

  bool get _passwordsMatch =>
      _registerPasswordController.text.isNotEmpty &&
          _registerPasswordController.text ==
              _registerPasswordConfirmController.text;

  bool get _passwordConfirmHasValue =>
      _registerPasswordConfirmController.text.isNotEmpty;

  bool _isValidPhone(String value) {
    return RegExp(r'^01[0-9]-\d{3,4}-\d{4}$').hasMatch(value);
  }

  bool _isValidEmail(String value) {
    return RegExp(
      r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
    ).hasMatch(value);
  }

  bool get _canSubmitRegister {
    final String loginId = _registerIdController.text.trim();
    final String password = _registerPasswordController.text.trim();
    final String passwordConfirm =
    _registerPasswordConfirmController.text.trim();
    final String userName = _registerUserNameController.text.trim();
    final String phone = _registerPhoneController.text.trim();
    final String email = _buildRegisterEmail();

    return _isValidLoginId(loginId) &&
        _isValidPassword(password) &&
        password == passwordConfirm &&
        userName.isNotEmpty &&
        _isValidPhone(phone) &&
        _isValidEmail(email) &&
        _agreeTerms &&
        _agreePrivacy &&
        !_isLoading;
  }

  InputDecoration _inputDecoration({
    required String hintText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF111827),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFieldLabel({
    required String title,
    String? helperText,
    Widget? trailing,
  }) {
    return SizedBox(
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(width: 8),
          if (helperText != null)
            Expanded(
              child: Text(
                helperText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            )
          else
            const Spacer(),
          SizedBox(
            width: 58,
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ?? const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordMatchChip() {
    if (!_passwordConfirmHasValue) {
      return const SizedBox(
        width: 58,
        height: 32,
      );
    }

    return Container(
      width: 58,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _passwordsMatch
            ? const Color(0xFFECFDF3)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _passwordsMatch
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFFECACA),
        ),
      ),
      child: Text(
        _passwordsMatch ? '일치' : '불일치',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _passwordsMatch
              ? const Color(0xFF047857)
              : const Color(0xFFB91C1C),
        ),
      ),
    );
  }

  Widget _buildTextFieldBlock({
    required String title,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    String? helperText,
    Widget? trailingLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          title: title,
          helperText: helperText,
          trailing: trailingLabel,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          onChanged: onChanged,
          decoration: _inputDecoration(hintText: hintText),
        ),
      ],
    );
  }

  Widget _buildEmailDomainDropdown() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedEmailDomain,
        hint: const Text('선택하세요'),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: Colors.white,
        items: const [
          DropdownMenuItem(
            value: 'naver.com',
            child: Text('naver.com'),
          ),
          DropdownMenuItem(
            value: 'gmail.com',
            child: Text('gmail.com'),
          ),
          DropdownMenuItem(
            value: 'daum.net',
            child: Text('daum.net'),
          ),
          DropdownMenuItem(
            value: 'kakao.com',
            child: Text('kakao.com'),
          ),
          DropdownMenuItem(
            value: 'direct',
            child: Text('직접입력'),
          ),
        ],
        onChanged: _isLoading
            ? null
            : (value) {
          setState(() {
            _selectedEmailDomain = value;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWide = constraints.maxWidth >= 1000;
        final bool useScroll = constraints.maxHeight < 820;

        final Widget formCard = ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isWide ? 980 : 760,
          ),
          child: Container(
            padding: EdgeInsets.all(isWide ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
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
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '회원가입',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _isLoading ? null : widget.onCloseRegisterView,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '계정을 생성하고 경제 시뮬레이션을 시작해 보세요.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                if (isWide)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFieldBlock(
                              title: 'ID',
                              controller: _registerIdController,
                              hintText: 'ID',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFieldBlock(
                              title: '사용자명',
                              controller: _registerUserNameController,
                              hintText: '사용자명',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFieldBlock(
                              title: '비밀번호',
                              controller: _registerPasswordController,
                              hintText: '비밀번호',
                              obscureText: true,
                              helperText: '소문자, 숫자 포함 8자 이상',
                              trailingLabel: const SizedBox(
                                width: 58,
                                height: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextFieldBlock(
                              title: '비밀번호 확인',
                              controller: _registerPasswordConfirmController,
                              hintText: '비밀번호 확인',
                              obscureText: true,
                              trailingLabel: _buildPasswordMatchChip(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextFieldBlock(
                              title: '연락처',
                              controller: _registerPhoneController,
                              hintText: '010-1234-5678',
                              keyboardType: TextInputType.phone,
                              onChanged: _onPhoneChanged,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel(title: '이메일'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _registerEmailIdController,
                                        decoration: _inputDecoration(
                                          hintText: '이메일 아이디',
                                        ),
                                      ),
                                    ),
                                    const Padding(
                                      padding:
                                      EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '@',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: _selectedEmailDomain == 'direct'
                                          ? TextField(
                                        controller:
                                        _registerEmailDomainDirectController,
                                        decoration: _inputDecoration(
                                          hintText: '직접입력',
                                        ),
                                      )
                                          : _buildEmailDomainDropdown(),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      _buildTextFieldBlock(
                        title: 'ID',
                        controller: _registerIdController,
                        hintText: 'ID',
                      ),
                      const SizedBox(height: 14),
                      _buildTextFieldBlock(
                        title: '사용자명',
                        controller: _registerUserNameController,
                        hintText: '사용자명',
                      ),
                      const SizedBox(height: 14),
                      _buildTextFieldBlock(
                        title: '비밀번호',
                        controller: _registerPasswordController,
                        hintText: '비밀번호',
                        obscureText: true,
                        helperText: '소문자, 숫자 포함 8자 이상',
                        trailingLabel: const SizedBox(
                          width: 58,
                          height: 32,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildTextFieldBlock(
                        title: '비밀번호 확인',
                        controller: _registerPasswordConfirmController,
                        hintText: '비밀번호 확인',
                        obscureText: true,
                        trailingLabel: _buildPasswordMatchChip(),
                      ),
                      const SizedBox(height: 14),
                      _buildTextFieldBlock(
                        title: '연락처',
                        controller: _registerPhoneController,
                        hintText: '010-1234-5678',
                        keyboardType: TextInputType.phone,
                        onChanged: _onPhoneChanged,
                      ),
                      const SizedBox(height: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel(title: '이메일'),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _registerEmailIdController,
                                  decoration: _inputDecoration(
                                    hintText: '이메일 아이디',
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '@',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _selectedEmailDomain == 'direct'
                                    ? TextField(
                                  controller:
                                  _registerEmailDomainDirectController,
                                  decoration: _inputDecoration(
                                    hintText: '직접입력',
                                  ),
                                )
                                    : _buildEmailDomainDropdown(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeTerms &&
                                _agreePrivacy &&
                                _agreeMarketing,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                              final bool checked = value ?? false;
                              setState(() {
                                _agreeTerms = checked;
                                _agreePrivacy = checked;
                                _agreeMarketing = checked;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '전체 동의',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 18),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeTerms,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                              setState(() {
                                _agreeTerms = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '이용약관 동의 (필수)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreePrivacy,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                              setState(() {
                                _agreePrivacy = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '개인정보 수집 및 이용 동의 (필수)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeMarketing,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                              setState(() {
                                _agreeMarketing = value ?? false;
                              });
                            },
                          ),
                          const Expanded(
                            child: Text(
                              '마케팅 정보 수신 동의 (선택)',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                        _isLoading ? null : widget.onCloseRegisterView,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFD1D5DB),
                          ),
                        ),
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _canSubmitRegister ? _signUp : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                            : const Text(
                          '회원가입 완료',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );

        return Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: useScroll
              ? SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(child: formCard),
          )
              : Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Center(child: formCard),
          ),
        );
      },
    );
  }
}