import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _auth = AuthService();

  bool _isRegister = false;
  bool _hidePassword = true;
  bool _loading = false;
  String _role = 'customer';

  final Color primary = const Color(0xFF7041D8);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      if (_isRegister) {
        await _auth.register(
          fullName: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: _role,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สมัครสมาชิกแล้ว กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชี'),
          ),
        );

        setState(() => _isRegister = false);
      } else {
        await _auth.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
    } on Exception catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _forgotPassword() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('กรุณากรอกอีเมลก่อน')));
      return;
    }

    try {
      await _auth.resetPassword(_emailController.text);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ส่งลิงก์รีเซ็ตรหัสผ่านแล้ว')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF7F7FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.handyman_outlined, size: 58, color: primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Promatchfix',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ค้นหาช่างและบริการที่คุณไว้วางใจ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      _isRegister ? 'สร้างบัญชีใหม่' : 'ยินดีต้อนรับกลับมา',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameController,
                        decoration: _decoration(
                          'ชื่อ-นามสกุล',
                          Icons.person_outline,
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'กรุณากรอกชื่อ-นามสกุล'
                            : null,
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'ประเภทบัญชี',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),

                      DropdownButtonFormField<String>(
                        initialValue: _role,
                        decoration: _decoration(
                          'ประเภทผู้ใช้งาน',
                          Icons.badge_outlined,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'customer',
                            child: Text('ลูกค้า'),
                          ),
                          DropdownMenuItem(
                            value: 'technician',
                            child: Text('ช่าง'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _role = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration('อีเมล', Icons.email_outlined),
                      validator: (v) =>
                          v == null ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim())
                          ? 'กรุณากรอกอีเมลให้ถูกต้อง'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: _hidePassword,
                      decoration: _decoration('รหัสผ่าน', Icons.lock_outline)
                          .copyWith(
                            suffixIcon: IconButton(
                              icon: Icon(
                                _hidePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(() => _hidePassword = !_hidePassword);
                              },
                            ),
                          ),
                      validator: (v) => v == null || v.length < 8
                          ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'
                          : null,
                    ),

                    if (!_isRegister)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: const Text('ลืมรหัสผ่าน?'),
                        ),
                      ),

                    const SizedBox(height: 20),

                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                _isRegister ? 'สมัครสมาชิก' : 'เข้าสู่ระบบ',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isRegister ? 'มีบัญชีอยู่แล้ว? ' : 'ยังไม่มีบัญชี? ',
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isRegister = !_isRegister;
                            });
                          },
                          child: Text(
                            _isRegister ? 'เข้าสู่ระบบ' : 'สมัครสมาชิก',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
