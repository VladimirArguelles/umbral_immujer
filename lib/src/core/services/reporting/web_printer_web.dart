import 'dart:async';
import 'dart:js_interop' as js;
import 'package:web/web.dart' as web;
import 'web_printer.dart';

/// Implementación web para imprimir directamente mediante el motor nativo del navegador (`window.print()`).
/// 
/// En dispositivos móviles (Android / iOS) y navegadores modernos, esto conecta directamente
/// con el Administrador de Impresión del Sistema Operativo (Spooler de Android, AirPrint en iOS)
/// SIN abrir ventanas emergentes (evitando bloqueos de popups) y SIN descargar archivos en disco.
Future<bool> printHtmlViaBrowser(String htmlContent, {String title = 'Reporte'}) async {
  if (!enableWebPrint) return false;
  try {
    final doc = web.document;

    final originalTitle = doc.title;
    if (title.isNotEmpty) {
      doc.title = title;
    }

    // 1. Limpieza de elementos previos si existieran
    doc.getElementById('__umbral_print_container__')?.remove();
    doc.getElementById('__umbral_print_style__')?.remove();

    // 2. Crear el contenedor que alojará el reporte a imprimir
    final container = doc.createElement('div') as web.HTMLDivElement;
    container.id = '__umbral_print_container__';
    container.innerHTML = htmlContent.toJS;

    // 3. Crear los estilos @media print dedicados:
    // Oculta absolutamente todos los elementos de Flutter en el documento y
    // muestra exclusivamente el contenedor del informe con formato blanco y negro/color nítido.
    final style = doc.createElement('style') as web.HTMLStyleElement;
    style.id = '__umbral_print_style__';
    style.textContent = '''
@media screen {
  #__umbral_print_container__ {
    display: none !important;
  }
}
@media print {
  @page {
    margin: 1cm;
  }
  html, body {
    margin: 0 !important;
    padding: 0 !important;
    background: #ffffff !important;
    background-color: #ffffff !important;
    height: auto !important;
    overflow: visible !important;
  }
  body > *:not(#__umbral_print_container__) {
    display: none !important;
  }
  #boot-container, flt-glass-pane, flutter-view, flt-scene-host {
    display: none !important;
  }
  #__umbral_print_container__ {
    display: block !important;
    position: static !important;
    width: 100% !important;
    margin: 0 !important;
    padding: 0 !important;
    background: #ffffff !important;
    color: #111827 !important;
    visibility: visible !important;
  }
  #__umbral_print_container__ * {
    visibility: visible !important;
  }
}
''';

    doc.head?.append(style);
    doc.body?.append(container);

    // 4. Pequeña espera asíncrona para que el DOM aplique el nuevo árbol y hojas de estilo
    await Future.delayed(const Duration(milliseconds: 250));

    // 5. Invocar el diálogo de impresión nativo del navegador (Android Spooler / AirPrint / Sistema)
    web.window.print();

    // 6. Programar la remoción limpia de los elementos inyectados tras finalizar
    Timer(const Duration(seconds: 4), () {
      try {
        container.remove();
        style.remove();
        doc.title = originalTitle;
      } catch (_) {}
    });

    return true;
  } catch (_) {
    return false;
  }
}

