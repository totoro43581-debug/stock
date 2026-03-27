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

  // 수정1차: 중복체크 콜백 추가
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
  // 수정1차: 이메일 분리
  final TextEditingController _emailIdController = TextEditingController();
  String _selectedDomain = 'naver.com';

  // 수정1차: 중복체크 상태
  bool? _isIdValid;
  bool? _isEmailValid;

  // 수정1차: 약관
  bool _agreeAll = false;
  bool _agreeTerms = false;
  bool _agreePrivacy = false;
  bool _agreeMarketing = false;

  // =========================
  // 수정1차: ID 중복체크
  // =========================
  Future<void> _checkId() async {
    final id = widget.idController.text.trim();
    if (id.isEmpty) return;

    final result = await widget.onCheckId(id);
    setState(() {
      _isIdValid = result;
    });
  }

  // =========================
  // 수정1차: 이메일 중복체크
  // =========================
  Future<void> _checkEmail() async {
    final email =
        '${_emailIdController.text.trim()}@$_selectedDomain';

    final result = await widget.onCheckEmail(email);

    setState(() {
      _isEmailValid = result;
      widget.emailController.text = email;
    });
  }

  // =========================
  // 수정1차: 전화번호 포맷
  // =========================
  void _formatPhone(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    String result = digits;

    if (digits.length > 3 && digits.length <= 7) {
      result = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length > 7) {
      result =
      '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }

    widget.phoneController.value = TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }

  // =========================
  // 수정1차: UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F5F9),
      child: Center(
        child: Container(
          width: 1100,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // 상단
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '회원가입',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: widget.onTapLogin,
                    icon: const Icon(Icons.close),
                  )
                ],
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  // ================= LEFT =================
                  Expanded(
                    child: Column(
                      children: [
                        _field('ID', widget.idController),
                        _checkButton(_checkId),
                        _statusText(_isIdValid),

                        _field('비밀번호', widget.passwordController,
                            obscure: true),
                        _field('비밀번호 확인',
                            widget.passwordConfirmController,
                            obscure: true),

                        _field('연락처', widget.phoneController,
                            onChanged: _formatPhone),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // ================= RIGHT =================
                  Expanded(
                    child: Column(
                      children: [
                        _field('사용자명', widget.userNameController),

                        Row(
                          children: [
                            Expanded(
                              child: _field(
                                  '이메일', _emailIdController),
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<String>(
                              value: _selectedDomain,
                              items: ['naver.com', 'gmail.com']
                                  .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedDomain = v!;
                                });
                              },
                            ),
                          ],
                        ),
                        _checkButton(_checkEmail),
                        _statusText(_isEmailValid),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              CheckboxListTile(
                value: _agreeAll,
                onChanged: (v) {
                  setState(() {
                    _agreeAll = v!;
                    _agreeTerms = v;
                    _agreePrivacy = v;
                    _agreeMarketing = v;
                  });
                },
                title: const Text('전체 동의'),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onTapLogin,
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: widget.onSubmit,
                      child: const Text('회원가입 완료'),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {bool obscure = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _checkButton(VoidCallback onTap) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: onTap,
        child: const Text('중복확인'),
      ),
    );
  }

  Widget _statusText(bool? value) {
    if (value == null) return const SizedBox();
    return Text(
      value ? '사용 가능합니다.' : '이미 사용중입니다.',
      style: TextStyle(color: value ? Colors.green : Colors.red),
    );
  }
}