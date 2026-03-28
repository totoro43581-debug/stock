import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RegisterViewSection extends StatefulWidget {
  final TextEditingController idController;
  final TextEditingController passwordController;
  final TextEditingController passwordConfirmController;
  final TextEditingController userNameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;

  final String? errorMessage;
  final bool isLoading;

  final VoidCallback onSubmit;
  final VoidCallback onTapLogin;

  // 수정1차: 중복체크 콜백
  // true = 사용 가능 / false = 이미 사용중
  final Future<bool> Function(String id) onCheckId;
  final Future<bool> Function(String email) onCheckEmail;

  const RegisterViewSection({
    super.key,
    required this.idController,
    required this.passwordController,
    required this.passwordConfirmController,
    required this.userNameController,
    required this.phoneController,
    required this.emailController,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
    required this.onTapLogin,
    required this.onCheckId,
    required this.onCheckEmail,
  });

  @override
  State<RegisterViewSection> createState() => _RegisterViewSectionState();
}

class _RegisterViewSectionState extends State<RegisterViewSection> {
  // 수정2차: 이메일 아이디/도메인 분리
  final TextEditingController _emailIdController = TextEditingController();

  final List<String> _domainList = <String>[
    'naver.com',
    'gmail.com',
    'daum.net',
    'hanmail.net',
    'kakao.com',
    'nate.com',
  ];

  String _selectedDomain = 'naver.com';

  // 수정3차: 중복체크 상태
  bool? _isIdAvailable;
  bool? _isEmailAvailable;

  // 수정4차: 안내 문구 상태
  String? _idStatusMessage;
  String? _emailStatusMessage;

  // 수정5차: 비밀번호 일치 상태
  bool _isPasswordMatched = false;

  // 수정6차: 약관 동의 상태
  bool _agreeAll = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  // 수정7차: 체크중 상태
  bool _isCheckingId = false;
  bool _isCheckingEmail = false;

  @override
  void initState() {
    super.initState();

    // 수정8차: 기존 emailController 값 분리 반영
    _syncEmailFromOuterController();

    widget.passwordController.addListener(_updatePasswordMatchState);
    widget.passwordConfirmController.addListener(_updatePasswordMatchState);

    widget.idController.addListener(_resetIdCheckState);
    _emailIdController.addListener(_resetEmailCheckState);
  }

  @override
  void dispose() {
    widget.passwordController.removeListener(_updatePasswordMatchState);
    widget.passwordConfirmController.removeListener(_updatePasswordMatchState);

    widget.idController.removeListener(_resetIdCheckState);
    _emailIdController.removeListener(_resetEmailCheckState);

    _emailIdController.dispose();
    super.dispose();
  }

  // 수정9차: 외부 emailController 값에서 아이디/도메인 추출
  void _syncEmailFromOuterController() {
    final String email = widget.emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      return;
    }

    final List<String> parts = email.split('@');
    if (parts.length != 2) {
      return;
    }

    _emailIdController.text = parts[0];

    if (_domainList.contains(parts[1])) {
      _selectedDomain = parts[1];
    }
  }

  // 수정10차: ID 변경 시 중복체크 상태 초기화
  void _resetIdCheckState() {
    if (_isIdAvailable != null || _idStatusMessage != null) {
      setState(() {
        _isIdAvailable = null;
        _idStatusMessage = null;
      });
    }
  }

  // 수정11차: 이메일 변경 시 중복체크 상태 초기화
  void _resetEmailCheckState() {
    if (_isEmailAvailable != null || _emailStatusMessage != null) {
      setState(() {
        _isEmailAvailable = null;
        _emailStatusMessage = null;
      });
    }
  }

  // 수정12차: 비밀번호 일치 여부 갱신
  void _updatePasswordMatchState() {
    final String password = widget.passwordController.text.trim();
    final String confirm = widget.passwordConfirmController.text.trim();

    final bool nextValue =
        password.isNotEmpty && confirm.isNotEmpty && password == confirm;

    if (_isPasswordMatched != nextValue) {
      setState(() {
        _isPasswordMatched = nextValue;
      });
    }
  }

  // 수정13차: 아이디 중복체크
  Future<void> _checkId() async {
    final String id = widget.idController.text.trim();

    if (id.isEmpty) {
      setState(() {
        _isIdAvailable = null;
        _idStatusMessage = 'ID를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isCheckingId = true;
      _idStatusMessage = null;
    });

    try {
      final bool result = await widget.onCheckId(id);

      if (!mounted) return;

      setState(() {
        _isIdAvailable = result;
        _idStatusMessage = result
            ? '사용 가능한 ID입니다.'
            : '이미 사용 중인 ID입니다.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isIdAvailable = null;
        _idStatusMessage = 'ID 중복확인 중 오류가 발생했습니다.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isCheckingId = false;
      });
    }
  }

  // 수정14차: 이메일 중복체크
  Future<void> _checkEmail() async {
    final String emailId = _emailIdController.text.trim();

    if (emailId.isEmpty) {
      setState(() {
        _isEmailAvailable = null;
        _emailStatusMessage = '이메일을 입력해주세요.';
      });
      return;
    }

    final String email = '$emailId@$_selectedDomain';

    setState(() {
      _isCheckingEmail = true;
      _emailStatusMessage = null;
    });

    try {
      final bool result = await widget.onCheckEmail(email);

      if (!mounted) return;

      setState(() {
        _isEmailAvailable = result;
        _emailStatusMessage = result
            ? '사용 가능한 이메일입니다.'
            : '이미 사용 중인 이메일입니다.';
        widget.emailController.text = email;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isEmailAvailable = null;
        _emailStatusMessage = '이메일 중복확인 중 오류가 발생했습니다.';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isCheckingEmail = false;
      });
    }
  }

  // 수정15차: 전화번호 자동 포맷
  void _formatPhone(String value) {
    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    String result = digits;

    if (digits.length > 3 && digits.length <= 7) {
      result = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length > 7 && digits.length <= 11) {
      result =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    } else if (digits.length > 11) {
      result =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7, 11)}';
    }

    widget.phoneController.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }

  // 수정16차: 전체동의 토글
  void _toggleAgreeAll(bool? value) {
    final bool checked = value ?? false;

    setState(() {
      _agreeAll = checked;
      _agreeTerms = checked;
      _agreePrivacy = checked;
      _agreeMarketing = checked;
    });
  }

  // 수정17차: 개별 체크 후 전체동의 상태 동기화
  void _syncAgreeAll() {
    final bool allChecked = _agreeTerms && _agreePrivacy && _agreeMarketing;

    if (_agreeAll != allChecked) {
      setState(() {
        _agreeAll = allChecked;
      });
    }
  }

  // 수정18차: 회원가입 버튼 활성 조건
  bool get _canSubmit {
    return !widget.isLoading &&
        !_isCheckingId &&
        !_isCheckingEmail &&
        widget.idController.text.trim().isNotEmpty &&
        widget.passwordController.text.trim().isNotEmpty &&
        widget.passwordConfirmController.text.trim().isNotEmpty &&
        widget.userNameController.text.trim().isNotEmpty &&
        widget.phoneController.text.trim().isNotEmpty &&
        _emailIdController.text.trim().isNotEmpty &&
        _isIdAvailable == true &&
        _isEmailAvailable == true &&
        _isPasswordMatched &&
        _agreeTerms &&
        _agreePrivacy;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F7FA),
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 980),
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: const Color(0xFFD9DEE5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '회원가입',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111827),
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '계정을 생성하고 경제 시뮬레이션을 시작해 보세요.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: widget.isLoading ? null : widget.onTapLogin,
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 28,
                          color: Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                if (widget.errorMessage != null &&
                    widget.errorMessage!.trim().isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDA4AF)),
                    ),
                    child: Text(
                      widget.errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBE123C),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLeftColumn()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRightColumn()),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFD9DEE5)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _agreeAll,
                            onChanged: _toggleAgreeAll,
                            activeColor: const Color(0xFF6D56C1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Text(
                            '전체 동의',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                        height: 18,
                        thickness: 1,
                        color: Color(0xFFE5E7EB),
                      ),
                      _buildAgreeRow(
                        title: '이용약관 동의 (필수)',
                        value: _agreeTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreeTerms = value ?? false;
                          });
                          _syncAgreeAll();
                        },
                      ),
                      _buildAgreeRow(
                        title: '개인정보 수집 및 이용 동의 (필수)',
                        value: _agreePrivacy,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreePrivacy = value ?? false;
                          });
                          _syncAgreeAll();
                        },
                      ),
                      _buildAgreeRow(
                        title: '마케팅 정보 수신 동의 (선택)',
                        value: _agreeMarketing,
                        onChanged: (bool? value) {
                          setState(() {
                            _agreeMarketing = value ?? false;
                          });
                          _syncAgreeAll();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: widget.isLoading ? null : widget.onTapLogin,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFFD1D5DB),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6D56C1),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? widget.onSubmit : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: const Color(0xFF3166E3),
                            disabledBackgroundColor: const Color(0xFFE7EAF0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: widget.isLoading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                              : const Text(
                            '회원가입 완료',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('ID'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller: widget.idController,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              height: 48,
              child: OutlinedButton(
                onPressed: _isCheckingId ? null : _checkId,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: _isCheckingId
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text(
                  '중복확인',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D56C1),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildStatusMessage(
          message: _idStatusMessage,
          isPositive: _isIdAvailable == true,
        ),
        const SizedBox(height: 18),
        _buildFieldLabelWithHint('비밀번호', '소문자, 숫자 포함 8자 이상'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: widget.passwordController,
          obscureText: true,
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('연락처'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: widget.phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
          ],
          onChanged: _formatPhone,
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('사용자명'),
        const SizedBox(height: 8),
        _buildTextField(
          controller: widget.userNameController,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                '비밀번호 확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
            if (_isPasswordMatched)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7EF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: const Color(0xFFA7E0BE),
                  ),
                ),
                child: const Text(
                  '일치',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F9F5A),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _buildTextField(
          controller: widget.passwordConfirmController,
          obscureText: true,
        ),
        const SizedBox(height: 18),
        _buildFieldLabel('이메일'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _buildTextField(
                controller: _emailIdController,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Text(
                '@',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD1D5DB),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedDomain,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(14),
                    items: _domainList.map((String domain) {
                      return DropdownMenuItem<String>(
                        value: domain,
                        child: Text(
                          domain,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF374151),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value == null) return;

                      setState(() {
                        _selectedDomain = value;
                        _isEmailAvailable = null;
                        _emailStatusMessage = null;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 110,
              height: 48,
              child: OutlinedButton(
                onPressed: _isCheckingEmail ? null : _checkEmail,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white,
                ),
                child: _isCheckingEmail
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Text(
                  '중복확인',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6D56C1),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _buildStatusMessage(
          message: _emailStatusMessage,
          isPositive: _isEmailAvailable == true,
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1F2937),
      ),
    );
  }

  Widget _buildFieldLabelWithHint(String title, String hint) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          hint,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFFD1D5DB),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF3166E3),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusMessage({
    required String? message,
    required bool isPositive,
  }) {
    if (message == null || message.trim().isEmpty) {
      return const SizedBox(height: 20);
    }

    return SizedBox(
      height: 20,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isPositive
                ? const Color(0xFF0F9F5A)
                : const Color(0xFFE11D48),
          ),
        ),
      ),
    );
  }

  Widget _buildAgreeRow({
    required String title,
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    return Row(
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6D56C1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}