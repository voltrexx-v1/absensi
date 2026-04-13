// Conditional export: loads web_camera_web.dart on web, stub on other platforms
export 'web_camera_stub.dart' if (dart.library.html) 'web_camera_web.dart';
