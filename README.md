# kyungnam_flutter_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 실행 준비 (Windows 기준)

1) Flutter/Android Studio 설치 후 환경 점검

```bash
flutter doctor
```

2) 프로젝트 의존성 설치

```bash
cd kyungnam_flutter_app
flutter pub get
```

## 디바이스(에뮬레이터/실기기) 확인

```bash
flutter devices            # 인식된 모든 디바이스 목록
flutter emulators          # 등록된 에뮬레이터 목록
flutter emulators --launch <emulator_id>  # 에뮬레이터 실행
```

- 물리 Android 기기: 개발자 옵션 → USB 디버깅 켜고 PC에 연결 후 아래 명령으로 확인

```bash
adb devices
```

인증(unauthorized)이면 기기에서 USB 디버깅 허용을 승인하세요.

## 앱 실행

기본 실행(자동 선택된 디바이스):

```bash
flutter run
```

특정 디바이스로 실행:

```bash
flutter run -d <device_id>
# 예) flutter run -d emulator-5554
# 예) flutter run -d chrome
```

실행 중 단축키:
- r: Hot Reload
- R: Hot Restart

로그 보기:

```bash
flutter logs
```

## 플랫폼별 안내

### Android
- 에뮬레이터를 켜거나 USB 디버깅이 활성화된 물리 기기를 연결하세요.
- 권한/드라이버 문제가 있으면 `flutter doctor` 와 `flutter doctor --android-licenses`를 확인/승인하세요.

### iOS (macOS 필요)
- Xcode 및 CocoaPods 설치가 필요합니다.
- 실행:

```bash
flutter run -d ios
```

- 또는 Xcode로 `ios/Runner.xcworkspace`를 열어 실행합니다.

### Web

처음 한 번만 Web 활성화:

```bash
flutter config --enable-web
```

실행:

```bash
flutter run -d chrome
```

### Windows 데스크톱 (옵션)

처음 한 번만 활성화:

```bash
flutter config --enable-windows-desktop
```

실행:

```bash
flutter run -d windows
```

## 빌드(배포용)

Android APK:

```bash
flutter build apk --release
```

Android App Bundle(Play 스토어 권장):

```bash
flutter build appbundle --release
```

iOS(맥 필요):

```bash
flutter build ipa --release
```

## 트러블슈팅

- 디바이스가 표시되지 않음: Android SDK/Platform-Tools 설치, 드라이버 설치, `flutter doctor` 확인.
- `unauthorized` 기기: 폰에서 USB 디버깅 승인 창 수락 후 다시 연결.
- Gradle/캐시 문제: `flutter clean && flutter pub get`.
- 카메라 권한 오류: Android는 `AndroidManifest.xml`, iOS는 `Info.plist`의 사용 권한 문자열(NSCameraUsageDescription) 확인.