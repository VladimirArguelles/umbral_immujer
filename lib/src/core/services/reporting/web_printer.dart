export 'web_printer_stub.dart'
    if (dart.library.js_interop) 'web_printer_web.dart';

/// Flag configurable mediante compilación (--dart-define=ENABLE_WEB_PRINT=true/false)
const bool enableWebPrint = bool.fromEnvironment('ENABLE_WEB_PRINT', defaultValue: true);
