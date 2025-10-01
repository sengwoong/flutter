import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart';
import 'dart:async';

class UploadScreen extends StatefulWidget {
  @override
  _UploadScreenState createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isStreaming = false;
  Timer? _streamingTimer;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라를 찾을 수 없습니다.')),
      );
      return;
    }

    // 카메라 권한 요청
    final status = await Permission.camera.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 권한이 필요합니다.')),
      );
      return;
    }

    // 전면 카메라 찾기
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );
    
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    } catch (e) {
      print('카메라 초기화 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화에 실패했습니다.')),
      );
    }
  }

  void _startStreaming() {
    if (_isStreaming || !_isCameraInitialized) return;

    setState(() {
      _isStreaming = true;
    });

    _streamingTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (!_isStreaming || _cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        final image = await _cameraController!.takePicture();
        // MediaPipeline에 전송하는 로직 (시뮬레이션)
        print('MediaPipeline frame sent: ${image.path}');
      } catch (e) {
        print('사진 촬영 오류: $e');
      }
    });
  }

  void _stopStreaming() {
    _streamingTimer?.cancel();
    setState(() {
      _isStreaming = false;
    });
  }

  @override
  void dispose() {
    _streamingTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('발 뜨기'),
        backgroundColor: Color(0xFF003A56),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Camera Section
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _isCameraInitialized
                    ? CameraPreview(_cameraController!)
                    : _buildUploadArea(),
              ),
            ),
          ),

          // Footer Section
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                // Streaming Toggle
                Row(
                  children: [
                    Checkbox(
                      value: _isStreaming,
                      onChanged: (value) {
                        if (value == true) {
                          _startStreaming();
                        } else {
                          _stopStreaming();
                        }
                      },
                      activeColor: Color(0xFF003A56),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isStreaming ? '스트리밍 중지' : '스트리밍 시작',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // Close Button
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF003B4A),
                      padding: EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Text(
                      '닫기',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey[400]!,
          style: BorderStyle.solid,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt_outlined,
              size: 64,
              color: Colors.grey[600],
            ),
            SizedBox(height: 16),
            Text(
              '카메라 권한이 필요합니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
