import 'package:flutter/material.dart';

class CardModal extends StatelessWidget {
  final String title;
  final Widget child;

  const CardModal({
    Key? key,
    required this.title,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: 340,
      margin: EdgeInsets.only(top: -6),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE6EEF1)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 1,
            color: Color(0xFF003A56),
            margin: EdgeInsets.symmetric(horizontal: -16),
          ),
          SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    );
  }
}
