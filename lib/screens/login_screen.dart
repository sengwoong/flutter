import 'package:flutter/material.dart';
import '../widgets/card_modal.dart';
import '../widgets/input_field.dart';
import '../widgets/primary_button.dart';
import 'register_screen.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final footerHeight = (screenHeight * 0.3).round().toDouble();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.only(bottom: footerHeight + 16),
                child: Column(
                  children: [
                    // Content Top
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Column(
                        children: [
                          // Full Width Divider (React Native와 동일)
                          Container(
                            height: 4,
                            color: Color(0xFF003A56),
                            width: double.infinity,
                            margin: EdgeInsets.only(top: 50),
                          ),
                          SizedBox(height: 20),
                          // Card Modal (정확히 동일한 디자인)
                          Center(
                            child: CardModal(
                              title: "로그인",
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
                                  PrimaryButton(
                                    title: "로그인",
                                    onPressed: () {
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => MainScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    // Link Row (오른쪽 정렬)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            "회원가입",
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
            // Footer (절대 위치, React Native와 동일)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: footerHeight,
                decoration: BoxDecoration(
                  color: Color(0xFF003A56),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                ),
                child: Center(
                  child: Text(
                    "welcome",
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
    super.dispose();
  }
}
