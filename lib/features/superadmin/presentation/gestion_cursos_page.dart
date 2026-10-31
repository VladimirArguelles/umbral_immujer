import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class GestionCursosPage extends StatefulWidget {
  const GestionCursosPage({super.key});

  @override
  State<GestionCursosPage> createState() => _GestionCursosPageState();
}

class _GestionCursosPageState extends State<GestionCursosPage> {
  final SupabaseClient _supabase = SupabaseConfig.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _cursos = [];
  List<Map<String, dynamic>> _filteredCursos = [];
  List<Map<String, dynamic>> _profesores = [];

  String? _selectedStatus; // null means 'Todos'
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Obtener lista de profesores disponibles para asignación
      final profResponse = await _supabase
          .from('perfiles')
          .select('id, nombre_completo, cedula')
          .inFilter('rol', ['profesor', 'teacher'])
          .order('nombre_completo');

      // 2. Obtener lista de cursos con profesor y temas
      final cursosResponse = await _supabase
          .from('cursos')
          .select('''
            id,
            nombre,
            descripcion,
            horario,
            estado,
            profesor_id,
            temas,
            created_at,
            perfiles:profesor_id (
              id,
              nombre_completo,
              cedula
            )
          ''')
          .order('nombre');

      if (mounted) {
        setState(() {
          _profesores = List<Map<String, dynamic>>.from(profResponse as List);
          _cursos = List<Map<String, dynamic>>.from(cursosResponse as List);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar cursos: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCursos = _cursos.where((c) {
        final matchesStatus = _selectedStatus == null ||
            (c['estado'] != null &&
                c['estado'].toString().toLowerCase() == _selectedStatus!.toLowerCase());

        final nombre = (c['nombre'] ?? '').toString().toLowerCase();
        final descripcion = (c['descripcion'] ?? '').toString().toLowerCase();
        final horario = (c['horario'] ?? '').toString().toLowerCase();
        final profMap = c['perfiles'] as Map<String, dynamic>?;
        final profNombre = (profMap?['nombre_completo'] ?? '').toString().toLowerCase();

        final matchesQuery = query.isEmpty ||
            nombre.contains(query) ||
            descripcion.contains(query) ||
            horario.contains(query) ||
            profNombre.contains(query);

        return matchesStatus && matchesQuery;
      }).toList();
    });
  }

  Future<void> _showAddCursoDialog() async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final horarioCtrl = TextEditingController();
    String? selectedProfesorId;
    String selectedEstado = 'activo';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Añadir Nuevo Curso',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Curso *',
                      prefixIcon: Icon(Symbols.menu_book),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Propósito',
                      prefixIcon: Icon(Symbols.description),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: horarioCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Horario y Días (Ej: Martes 8:00 AM)',
                      prefixIcon: Icon(Symbols.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedProfesorId,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Profesor Asignado',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin profesor asignado'),
                      ),
                      ..._profesores.map((p) {
                        final n = p['nombre_completo'] as String;
                        final ci = p['cedula'] ?? '';
                        return DropdownMenuItem<String?>(
                          value: p['id'] as String,
                          child: Text('$n ($ci)'),
                        );
                      }),
                    ],
                    onChanged: (val) => setDialogState(() => selectedProfesorId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedEstado,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Estado del Curso',
                      prefixIcon: Icon(Symbols.toggle_on),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedEstado = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _supabase.from('cursos').insert({
                    'nombre': nombreCtrl.text.trim(),
                    'descripcion': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    'horario': horarioCtrl.text.trim().isNotEmpty ? horarioCtrl.text.trim() : null,
                    'profesor_id': selectedProfesorId,
                    'estado': selectedEstado,
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Curso añadido con éxito.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al añadir: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              icon: const Icon(Symbols.check),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCursoDialog(Map<String, dynamic> curso) async {
    final nombreCtrl = TextEditingController(text: curso['nombre'] ?? '');
    final descCtrl = TextEditingController(text: curso['descripcion'] ?? '');
    final horarioCtrl = TextEditingController(text: curso['horario'] ?? '');
    String? selectedProfesorId = curso['profesor_id'] as String?;
    String selectedEstado = (curso['estado'] as String?) ?? 'activo';

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Editar Curso',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nombreCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Curso *',
                      prefixIcon: Icon(Symbols.menu_book),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Descripción / Propósito',
                      prefixIcon: Icon(Symbols.description),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: horarioCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Horario y Días',
                      prefixIcon: Icon(Symbols.schedule),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedProfesorId,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Profesor Asignado',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin profesor asignado'),
                      ),
                      ..._profesores.map((p) {
                        final n = p['nombre_completo'] as String;
                        final ci = p['cedula'] ?? '';
                        return DropdownMenuItem<String?>(
                          value: p['id'] as String,
                          child: Text('$n ($ci)'),
                        );
                      }),
                    ],
                    onChanged: (val) => setDialogState(() => selectedProfesorId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedEstado,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Estado del Curso',
                      prefixIcon: Icon(Symbols.toggle_on),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'activo', child: Text('Activo')),
                      DropdownMenuItem(value: 'finalizado', child: Text('Finalizado')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedEstado = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _supabase.from('cursos').update({
                    'nombre': nombreCtrl.text.trim(),
                    'descripcion': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    'horario': horarioCtrl.text.trim().isNotEmpty ? horarioCtrl.text.trim() : null,
                    'profesor_id': selectedProfesorId,
                    'estado': selectedEstado,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', curso['id']);

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Curso actualizado con éxito.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: AppTheme.errorRed),
                    );
                  }
                }
              },
              icon: const Icon(Symbols.check),
              label: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCurso(Map<String, dynamic> curso) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Eliminación', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar el curso "${curso['nombre']}"?\n\nEsta acción eliminará las inscripciones, asistencias y encuestas relacionadas a este curso.',
          style: const TextStyle(color: AppTheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar Curso'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('cursos').delete().eq('id', curso['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Curso eliminado correctamente.')),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceContainerLow,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gestión de Cursos',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'Super Admin • Control de cursos, horarios, asignaciones y estados',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            tooltip: 'Guardar y Sincronizar Cambios',
            icon: const Icon(Symbols.sync, color: AppTheme.primary),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Barra de controles y filtros superiores
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: AppTheme.outlineVariant)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Filtro por Estado
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedStatus,
                        dropdownColor: AppTheme.surfaceContainer,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Estado',
                          prefixIcon: Icon(Symbols.filter_list, size: 20),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los Estados'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'activo',
                            child: Text('Cursos Activos'),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'finalizado',
                            child: Text('Cursos Finalizados'),
                          ),
                        ],
                        onChanged: (val) {
                          _selectedStatus = val;
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón Añadir Curso
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAddCursoDialog,
                      icon: const Icon(Symbols.add_circle, size: 20),
                      label: const Text('Añadir Curso'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Barra de Búsqueda
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Buscar curso por nombre, horario o profesor...',
                          prefixIcon: const Icon(Symbols.search, size: 20),
                          isDense: true,
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Symbols.close, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Chip(
                      backgroundColor: AppTheme.surfaceContainer,
                      label: Text(
                        'Total: ${_filteredCursos.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Cursos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Symbols.error, color: AppTheme.errorRed, size: 48),
                            const SizedBox(height: 12),
                            Text(_errorMessage!, style: const TextStyle(color: AppTheme.errorRed)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
                          ],
                        ),
                      )
                    : _filteredCursos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.menu_book, size: 64, color: AppTheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron cursos con estos filtros.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppTheme.onSurfaceVariant,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _filteredCursos.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final c = _filteredCursos[index];
                              final nombre = c['nombre'] ?? 'Sin Nombre';
                              final descripcion = c['descripcion'] ?? 'Sin descripción disponible';
                              final horario = c['horario'] ?? 'Horario por coordinar';
                              final estado = (c['estado'] as String?) ?? 'activo';
                              final profMap = c['perfiles'] as Map<String, dynamic>?;
                              final profNombre = profMap?['nombre_completo'] ?? 'Sin Profesor Asignado';
                              final temasCount = (c['temas'] is List) ? (c['temas'] as List).length : 0;

                              final isActivo = estado.toLowerCase() == 'activo';

                              return Card(
                                elevation: 0,
                                color: AppTheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: isActivo
                                            ? AppTheme.primaryContainer.withAlpha(40)
                                            : AppTheme.outlineVariant.withAlpha(40),
                                        foregroundColor: isActivo ? AppTheme.primary : AppTheme.outline,
                                        radius: 22,
                                        child: Icon(
                                          isActivo ? Symbols.menu_book : Symbols.archive,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    nombre,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 16,
                                                      color: AppTheme.onSurface,
                                                    ),
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isActivo
                                                        ? AppTheme.successGreen.withAlpha(30)
                                                        : AppTheme.outline.withAlpha(30),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    estado.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: isActivo ? AppTheme.successGreen : AppTheme.outline,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              descripcion,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppTheme.onSurfaceVariant,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.person, size: 14, color: AppTheme.primary),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      profNombre,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppTheme.primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.schedule, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(horario, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                                if (temasCount > 0)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(Symbols.topic, size: 14, color: AppTheme.tertiary),
                                                      const SizedBox(width: 4),
                                                      Text('$temasCount temas', style: const TextStyle(fontSize: 12, color: AppTheme.tertiary)),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Botones de acción: Editar y Eliminar
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Symbols.edit, color: AppTheme.primary, size: 20),
                                            tooltip: 'Editar Curso',
                                            onPressed: () => _showEditCursoDialog(c),
                                          ),
                                          IconButton(
                                            icon: const Icon(Symbols.delete, color: AppTheme.errorRed, size: 20),
                                            tooltip: 'Eliminar Curso',
                                            onPressed: () => _confirmDeleteCurso(c),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
