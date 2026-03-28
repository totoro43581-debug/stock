import 'package:flutter/material.dart';

class LoginCardSection extends StatelessWidget {
  final TextEditingController idController;
  final TextEditingController passwordController;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onTapLogin;
  final VoidCallback onTapRegister;

  const LoginCardSection({
    super.key,
    required this.idController,
    required this.passwordController,
    required this.errorMessage,
    required this.isLoading,
    required this.onTapLogin,
    required this.onTapRegister,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        errorMessage != null && errorMessage!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(32, 34, 32, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '로그인',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '아이디와 비밀번호를 입력해주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '아이디',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _LoginInputField(
            controller: idController,
            hintText: '아이디를 입력해주세요',
          ),
          const SizedBox(height: 16),
          const Text(
            '비밀번호',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          _LoginInputField(
            controller: passwordController,
            hintText: '비밀번호를 입력해주세요',
            obscureText: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 20,
            child: hasError
                ? Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFFE11D48),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            )
                : const SizedBox.shrink(),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : onTapLogin,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: const Color(0xFF0F172A),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : const Text(
                '로그인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: isLoading ? null : onTapRegister,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '회원가입',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6D56C1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;

  const _LoginInputField({
    required this.controller,
    required this.hintText,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 15,
          ),
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
              color: Color(0xFF6D56C1),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}