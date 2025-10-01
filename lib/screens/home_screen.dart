import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'main_screen.dart';
import 'pose_detection_screen.dart';
import 'ankle_measure_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 헤더
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Color(0xFF003A56),
                ),
                child: Column(
                  children: [
                    Text(
                      '경남대학교 낙상 위험 측정',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'AI 기반 실시간 포즈 감지 시스템',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFB8D4E3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // 히어로 섹션
              Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // 이미지 플레이스홀더
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.accessibility_new,
                        size: 100,
                        color: Color(0xFF003A56),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Google ML Kit을 활용한\n정확한 포즈 분석으로\n낙상 위험을 미리 예방하세요',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // 버튼 섹션
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildActionButton(
                      context,
                      '메인 화면으로',
                      '로그인하여 모든 기능 사용하기',
                      Color(0xFF003A56),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MainScreen()),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      context,
                      '로그인',
                      '계정으로 로그인하기',
                      Colors.grey[600]!,
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildActionButton(
                      context,
                      '발목 각도 측정하기',
                      '바로 발목 각도 측정 시작하기',
                      Color(0xFFE45745),
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AnkleMeasureScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 푸터
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                ),
                child: Text(
                  'Google ML Kit을 사용한\n정확한 수치 기반 포즈 감지',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String title,
    String subtitle,
    Color color,
    VoidCallback onPressed,
  ) {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPoseDetection(BuildContext context, String type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PoseDetectionScreen(
          detectionType: type,
        ),
      ),
    );
  }
}
