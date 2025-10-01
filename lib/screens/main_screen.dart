import 'package:flutter/material.dart';
import '../widgets/card_modal.dart';
import '../widgets/primary_button.dart';
import 'ankle_measure_screen.dart';
import 'pose_detection_screen.dart';
import 'upload_screen.dart';

class MainScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(bottom: 24), // scrollContent paddingBottom
            child: Column(
              children: [
                // Hero Wrap (React Native와 정확히 동일)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      // Full Width Divider
                      Container(
                        height: 4,
                        color: Color(0xFF003A56),
                        width: double.infinity,
                        margin: EdgeInsets.only(top: 50),
                      ),
                      SizedBox(height: 20),
                      // Hero Card
                      Center(
                        child: CardModal(
                          title: "지금당장 확인하세요",
                          child: Column(
                            children: [
                              // Hero Image Wrap
                              Expanded(
                                child: Container(
                                  width: double.infinity,
                                  margin: EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    width: double.infinity,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFEAF2F5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.accessibility_new,
                                      size: 80,
                                      color: Color(0xFF003A56),
                                    ),
                                  ),
                                ),
                              ),
                              PrimaryButton(
                                title: "간단하게 낙상 위험 확인하기",
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PoseDetectionScreen(
                                        detectionType: 'standup',
                                      ),
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
                
                // Section Header Row (React Native와 동일)
                Container(
                  margin: EdgeInsets.only(top: 16),
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "최근 낙상 기록",
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111111),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Text(
                          "더보기",
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF003A56),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // List Wrap (Records)
                Container(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: _buildRecordCards(),
                  ),
                ),

                // Actions Wrap (React Native와 동일)
                Container(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildActionButton(
                        "발목 각도 측정하기",
                        Color(0xFF003A56),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AnkleMeasureScreen(),
                          ),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildActionButton(
                        "팔 뻗기 측정하기",
                        Color(0xFF666666),
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PoseDetectionScreen(
                              detectionType: 'armstretch',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecordCards() {
    // React Native MOCK_RECORDS와 정확히 동일
    final mockRecords = [
      {
        'id': '1',
        'idText': 'id:151',
        'date': '2025-08-28 FRT (기능적 팔 뻗기 검사)',
        'title': '낙상위험 감지 안전을 취해주세요',
        'linkText': '경남대병원 앞로 바로가기',
        'dotColor': '#E45745',
      },
      {
        'id': '2',
        'idText': 'id:129',
        'date': '2025-08-28 FRT (기능적 팔 뻗기 검사)',
        'title': '한번더 첫번째 검사',
        'linkText': '경남대병원 앞 로비 바로가기',
        'dotColor': '#E6B645',
      },
      {
        'id': '3',
        'idText': 'id:122',
        'date': '2025-08-28 FRT (기능적 팔 뻗기 검사)',
        'title': '박민철 친구 검사',
        'linkText': '경남대병원 9층 로비 내부가기',
        'dotColor': '#E45745',
      },
    ];

    return mockRecords.map((record) => Container(
      // recordCard 스타일 정확히 복사
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE6EEF1), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // recordTopRow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                record['date'] as String,
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                ),
              ),
              Text(
                record['idText'] as String,
                style: TextStyle(
                  color: Color(0xFF777777),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          SizedBox(height: 6), // marginBottom: 6
          // recordTitle
          Container(
            margin: EdgeInsets.only(bottom: 8),
            child: Text(
              record['title'] as String,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // recordBottomRow
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  record['linkText'] as String,
                  style: TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Color(int.parse('0xFF${record['dotColor']!.substring(1)}')),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildActionButton(String title, Color color, VoidCallback onPressed) {
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
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
