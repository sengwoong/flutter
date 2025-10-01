import 'package:flutter/material.dart';
import '../widgets/card_modal.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final footerHeight = (screenHeight * 0.3).round().toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.only(bottom: footerHeight + 16),
                  child: Column(
                    children: [
                      // Content Top
                      Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            // Full Width Divider
                            Container(
                              height: 4,
                              color: Color(0xFF003A56),
                              margin: EdgeInsets.only(top: 50),
                            ),
                            SizedBox(height: 20),
                            // Card Modal
                            CardModal(
                              title: "회원가입",
                              child: Column(
                                children: [
                                  InputField(
                                    placeholder: "아이디",
                                    controller: _usernameController,
                                  ),
                                  InputField(
                                    placeholder: "비밀번호",
                                    obscureText: true,
                                    controller: _passwordController,
                                  ),
                                  InputField(
                                    placeholder: "비밀번호 확인",
                                    obscureText: true,
                                    controller: _confirmPasswordController,
                                  ),
                                  PrimaryButton(
                                    title: "회원가입",
                                    onPressed: () {
                                      // 간단한 유효성 검사
                                      if (_passwordController.text != _confirmPasswordController.text) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('비밀번호가 일치하지 않습니다.')),
                                        );
                                        return;
                                      }
                                      
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => LoginScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Link Row
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            },
                            child: Text(
                              "로그인으로 가기",
                              style: TextStyle(
                                color: Color(0xFF0A333D),
                                fontSize: 14,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              height: footerHeight,
              decoration: BoxDecoration(
                color: Color(0xFF003A56),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                ),
              ),
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => LoginScreen(),
                      ),
                    );
                  },
                  child: Text(
                    "Register",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
