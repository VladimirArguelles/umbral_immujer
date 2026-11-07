import 'dart:js_interop' as js;
import 'package:web/web.dart' as web;

/// Implementación web para abrir el documento HTML en una ventana/pestaña limpia
/// e invocar automáticamente `window.print()`, conectando con el spooler de Android/iOS o PC
/// de forma directa sin generar descargas de archivos PDF al disco.
Future<bool> printHtmlViaBrowser(String htmlContent, {String title = 'Reporte'}) async {
  try {
    final blob = web.Blob(
      [htmlContent.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);
    final win = web.window.open(url, '_blank');
    return win != null;
  } catch (_) {
    return false;
  }
}
