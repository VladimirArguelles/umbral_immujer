import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Shows a bottom sheet prompting the user to pick an image from Camera or Gallery.
Future<ImageSource?> showStudentReceiptSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: AppTheme.dynamicCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.dynamicBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Subir Capture de Pago',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            'Elige cómo deseas adjuntar tu comprobante de Pago Móvil',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.dynamicTextMuted),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.primary,
              child: Icon(Icons.camera_alt_rounded, color: Colors.white),
            ),
            title: const Text('Tomar Foto con Cámara'),
            subtitle: const Text('Captura directa del recibo o pantalla'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const Divider(height: 8),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppTheme.secondary,
              child: Icon(Icons.photo_library_rounded, color: Colors.white),
            ),
            title: const Text('Seleccionar de Galería'),
            subtitle: const Text('Elige una captura guardada en tu equipo'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
}

/// Shows an interactive zoomable dialog displaying a payment proof image URL.
void showStudentReceiptModal(
  BuildContext context, {
  required String url,
  String title = 'Comprobante de Pago',
  String? subtitle,
  String? statusLabel,
}) {
  final Color statusColor;
  switch (statusLabel?.toLowerCase()) {
    case 'verificado':
      statusColor = AppTheme.successGreen;
      break;
    case 'rechazado':
      statusColor = AppTheme.errorRed;
      break;
    default:
      statusColor = AppTheme.warningOrange;
  }

  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppTheme.dynamicCard,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.dynamicTextMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppTheme.errorRed,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No se pudo cargar la imagen del comprobante.',
                            style: TextStyle(color: AppTheme.dynamicTextMuted),
                          ),
                        ],
                      ),
                    ),
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
