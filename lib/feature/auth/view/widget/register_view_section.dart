import 'package:flutter/material.dart';

class RegisterViewSection extends StatelessWidget {
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '회원가입',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '회원 정보를 입력해주세요.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),
          _buildField(
            controller: idController,
            label: '아이디',
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: passwordController,
            label: '비밀번호',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: passwordConfirmController,
            label: '비밀번호 확인',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: userNameController,
            label: '이름',
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: phoneController,
            label: '연락처',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _buildField(
            controller: emailController,
            label: '이메일',
            keyboardType: TextInputType.emailAddress,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text(
                '회원가입 완료',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: isLoading ? null : onTapLogin,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD1D5DB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '로그인 화면으로',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}