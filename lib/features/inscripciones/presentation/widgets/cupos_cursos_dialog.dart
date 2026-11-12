import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:umbral_immujer/features/inscripciones/data/inscripciones_repository.dart';
import 'package:umbral_immujer/features/inscripciones/domain/inscripcion_models.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

/// Diálogo administrativo para establecer la cantidad de cupos disponibles
/// y estado de admisión por cada curso activo.
class CuposCursosDialog extends StatefulWidget {
  final InscripcionesRepository repository;

  const CuposCursosDialog({super.key, required this.repository});

  static Future<bool> show(
    BuildContext context, {
    required InscripcionesRepository repository,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => CuposCursosDialog(repository: repository),
    );
    return result ?? false;
  }

  @override
  State<CuposCursosDialog> createState() => _CuposCursosDialogState();
}

class _CuposCursosDialogState extends State<CuposCursosDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  final Map<String, TextEditingController> _cupoControllers = {};
  final Map<String, bool> _admisionStates = {};

  bool _isLoading = true;
  bool _hasChanges = false;
  String? _savingCursoId;
  String? _errorMessage;
  String _query = '';
  List<CursoConCupos> _cursos = [];

  @override
  void initState() {
    super.initState();
    _loadCursos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final ctrl in _cupoControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCursos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final cursos = await widget.repository.getCursosConCupos();
      if (!mounted) return;
      for (final ctrl in _cupoControllers.values) {
        ctrl.dispose();
      }
      _cupoControllers.clear();
      _admisionStates.clear();
      for (final c in cursos) {
        _cupoControllers[c.id] = TextEditingController(text: '${c.cupoMaximo}');
        _admisionStates[c.id] = c.admisionAbierta;
      }
      setState(() {
        _cursos = cursos;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudieron cargar los cursos: $e';
      });
    }
  }

  Future<void> _saveCursoCupo(CursoConCupos curso) async {
    final ctrl = _cupoControllers[curso.id];
    if (ctrl == null) return;

    final parsed = int.tryParse(ctrl.text.trim());
    if (parsed == null || parsed < 1 || parsed > 1000) {
      _showSnack('Ingresa un cupo válido entre 1 y 1000.', isError: true);
      return;
    }

    setState(() => _savingCursoId = curso.id);
    try {
      final admision = _admisionStates[curso.id] ?? curso.admisionAbierta;
      await widget.repository.setCursoCupo(
        cursoId: curso.id,
        cupoMaximo: parsed,
        admisionAbierta: admision,
      );
      if (!mounted) return;
      _hasChanges = true;
      _showSnack(
        'Cupo de "${curso.nombre}" actualizado a $parsed plazas.',
        isSuccess: true,
      );
      await _loadCursos();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error al guardar cupo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _savingCursoId = null);
    }
  }

  void _stepCupo(String cursoId, int delta) {
    final ctrl = _cupoControllers[cursoId];
    if (ctrl == null) return;
    final current = int.tryParse(ctrl.text.trim()) ?? 30;
    final next = (current + delta).clamp(1, 1000);
    setState(() {
      ctrl.text = '$next';
    });
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? AppTheme.errorRed
            : isSuccess
                ? AppTheme.successGreenVariant
                : AppTheme.surfaceContainerHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _cursos.where((c) {
      if (_query.isEmpty) return true;
      return c.nombre.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pop(_hasChanges);
        }
      },
      child: AlertDialog(
        backgroundColor: AppTheme.dynamicCard,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.dynamicBorder),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Symbols.event_seat,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cupos por Curso',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppTheme.dynamicText,
                    ),
                  ),
                  Text(
                    'Define la capacidad máxima y admisión de cada taller',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: AppTheme.dynamicTextMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Symbols.close, color: AppTheme.dynamicTextMuted),
              onPressed: () => Navigator.of(context).pop(_hasChanges),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 440,
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style: TextStyle(color: AppTheme.dynamicText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Buscar curso por nombre...',
                  prefixIcon: const Icon(Symbols.search, size: 18),
                  isDense: true,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Symbols.close, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _query = val.trim()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppTheme.errorRed,
                                    fontSize: 12.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: _loadCursos,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          )
                        : filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No se encontraron cursos activos.',
                                  style: TextStyle(
                                    color: AppTheme.dynamicTextMuted,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filtered.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final curso = filtered[index];
                                  return _buildCursoCupoRow(curso);
                                },
                              ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_hasChanges),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildCursoCupoRow(CursoConCupos curso) {
    final ctrl = _cupoControllers[curso.id]!;
    final admisionAbierta = _admisionStates[curso.id] ?? curso.admisionAbierta;
    final isSaving = _savingCursoId == curso.id;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dynamicSurfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dynamicBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curso.nombre,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: AppTheme.dynamicText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Inscritos actuales: ${curso.inscritosCount} / ${curso.cupoMaximo} '
                      '(${curso.cuposDisponibles} disponibles)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: curso.cuposAgotados
                            ? AppTheme.errorRed
                            : AppTheme.dynamicTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    admisionAbierta ? 'Abierto' : 'Cerrado',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: admisionAbierta
                          ? AppTheme.successGreen
                          : AppTheme.warningOrange,
                    ),
                  ),
                  Switch.adaptive(
                    value: admisionAbierta,
                    activeThumbColor: AppTheme.successGreen,
                    onChanged: isSaving
                        ? null
                        : (val) => setState(() => _admisionStates[curso.id] = val),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.outlined(
                onPressed: isSaving ? null : () => _stepCupo(curso.id, -1),
                icon: const Icon(Symbols.remove, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Disminuir cupo',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  enabled: !isSaving,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.dynamicText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Cupo máximo',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                onPressed: isSaving ? null : () => _stepCupo(curso.id, 1),
                icon: const Icon(Symbols.add, size: 16),
                visualDensity: VisualDensity.compact,
                tooltip: 'Aumentar cupo',
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: AppTheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onPressed: isSaving ? null : () => _saveCursoCupo(curso),
                icon: isSaving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.onPrimary,
                        ),
                      )
                    : const Icon(Symbols.save, size: 16),
                label: const Text('Guardar'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
