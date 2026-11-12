import 'package:flutter/material.dart';
import 'package:umbral_immujer/features/teacher/data/teacher_repository.dart';
import 'package:umbral_immujer/features/teacher/domain/teacher_models.dart';
import 'package:umbral_immujer/features/teacher/presentation/widgets/teacher_payment_dialogs.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';
import 'package:umbral_immujer/src/core/utils/formatters.dart';
import 'package:umbral_immujer/src/core/widgets/skeleton_loader.dart';

/// Revenue audit tab for inspecting and verifying student payment receipts per survey.
class TeacherRevenueAuditTab extends StatefulWidget {
  const TeacherRevenueAuditTab({
    super.key,
    required this.teacherRepository,
    this.isSuperAdmin = false,
  });

  final TeacherRepository teacherRepository;
  final bool isSuperAdmin;

  @override
  State<TeacherRevenueAuditTab> createState() => _TeacherRevenueAuditTabState();
}

class _TeacherRevenueAuditTabState extends State<TeacherRevenueAuditTab> {
  List<Map<String, dynamic>> _encuestas = [];
  String? _selectedEncuestaId;
  List<PaymentAuditItem> _recaudacion = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEncuestasDocente();
  }

  Future<void> _loadEncuestasDocente() async {
    setState(() => _isLoading = true);
    final data = await widget.teacherRepository.getAuditSurveysList();
    if (!mounted) return;
    setState(() {
      _encuestas = data;
      if (_encuestas.isNotEmpty) {
        _selectedEncuestaId = _encuestas.first['id'] as String;
      }
      _isLoading = false;
    });
    if (_selectedEncuestaId != null) {
      await _loadRecaudacion(_selectedEncuestaId!);
    }
  }

  Future<void> _loadRecaudacion(String encuestaId) async {
    setState(() => _isLoading = true);
    final items = await widget.teacherRepository.getSurveyPayments(encuestaId);
    if (!mounted) return;
    setState(() {
      _recaudacion = items;
      _isLoading = false;
    });
  }

  Future<void> _cambiarEstadoPago(
    PaymentAuditItem item,
    String nuevoEstado,
  ) async {
    await widget.teacherRepository.updatePaymentStatus(
      responseId: item.respuestaId,
      status: nuevoEstado,
    );
    if (_selectedEncuestaId != null) {
      await _loadRecaudacion(_selectedEncuestaId!);
    }
  }

  String _formatSurveyLabel(Map<String, dynamic> e) {
    final c = e['cursos'] as Map<String, dynamic>?;
    return '${c?['nombre'] ?? "Curso"} • Clase: ${e['fecha_clase']}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _encuestas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_encuestas.isEmpty) {
      return const Center(
        child: Text('No hay encuestas registradas para auditar.'),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: AppTheme.surfaceContainerLow,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedEncuestaId,
            decoration: const InputDecoration(
              labelText: 'Seleccionar Encuesta',
              prefixIcon: Icon(Icons.receipt_long),
            ),
            selectedItemBuilder: (context) => _encuestas
                .map(
                  (e) => Text(
                    _formatSurveyLabel(e),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                .toList(),
            items: _encuestas
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e['id'] as String,
                    child: Text(
                      _formatSurveyLabel(e),
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() => _selectedEncuestaId = val);
                _loadRecaudacion(val);
              }
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const SurveysSkeleton()
              : _recaudacion.isEmpty
                  ? const Center(
                      child: Text(
                        'Aún no hay respuestas de alumnos confirmados para esta práctica.',
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                      itemCount: _recaudacion.length,
                      itemBuilder: (context, idx) {
                        final item = _recaudacion[idx];
                        return _RevenuePaymentCard(
                          item: item,
                          onViewProof: () => showTeacherPaymentProofDialog(
                            context,
                            item.comprobanteUrl!,
                            title: 'Capture de Comprobante',
                          ),
                          onVerify: () =>
                              _cambiarEstadoPago(item, 'verificado'),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _RevenuePaymentCard extends StatelessWidget {
  const _RevenuePaymentCard({
    required this.item,
    required this.onViewProof,
    required this.onVerify,
  });

  final PaymentAuditItem item;
  final VoidCallback onViewProof;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    final hasReceipt =
        item.comprobanteUrl != null && item.comprobanteUrl!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.nombreCompleto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Text(
                  Formatters.currency(item.monto),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),
            Text(
              'C.I: ${item.cedula}',
              style: const TextStyle(
                color: AppTheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (hasReceipt)
                  OutlinedButton.icon(
                    onPressed: onViewProof,
                    icon: const Icon(Icons.image, size: 16),
                    label: const Text(
                      'Ver Capture',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else
                  const Text(
                    'Capture pendiente',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const Spacer(),
                if (item.estadoPago != 'verificado')
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                    ),
                    onPressed: onVerify,
                    child: const Text(
                      'Verificar',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.tertiary.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                    ),
                    child: const Text(
                      'VERIFICADO',
                      style: TextStyle(
                        color: AppTheme.successGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
