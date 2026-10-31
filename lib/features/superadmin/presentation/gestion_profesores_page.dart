import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:umbral_immujer/src/core/config/supabase_config.dart';
import 'package:umbral_immujer/src/core/theme/app_theme.dart';

class GestionProfesoresPage extends StatefulWidget {
  const GestionProfesoresPage({super.key});

  @override
  State<GestionProfesoresPage> createState() => _GestionProfesoresPageState();
}

class _GestionProfesoresPageState extends State<GestionProfesoresPage> {
  final SupabaseClient _supabase = SupabaseConfig.client;

  bool _isLoading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _cursos = [];
  List<Map<String, dynamic>> _profesores = [];
  List<Map<String, dynamic>> _filteredProfesores = [];

  String? _selectedCursoId; // null means 'Todos'
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
      // 1. Obtener cursos activos con su profesor asignado
      final cursosResponse = await _supabase
          .from('cursos')
          .select('id, nombre, profesor_id')
          .eq('estado', 'activo')
          .order('nombre');

      // 2. Obtener profesores de la tabla perfiles
      final profResponse = await _supabase
          .from('perfiles')
          .select('id, nombre_completo, cedula, telefono, correo, email, rol, user_id, created_at')
          .inFilter('rol', ['profesor', 'teacher'])
          .order('nombre_completo');

      final cursosList = List<Map<String, dynamic>>.from(cursosResponse as List);
      final profList = List<Map<String, dynamic>>.from(profResponse as List);

      // Asociar cursos a cada profesor
      for (final p in profList) {
        final pId = p['id'] as String;
        final cursosAsignados = cursosList
            .where((c) => c['profesor_id'] == pId)
            .map((c) => c['nombre'] as String)
            .toList();
        p['cursos_asignados'] = cursosAsignados;
        p['curso_ids'] = cursosList
            .where((c) => c['profesor_id'] == pId)
            .map((c) => c['id'] as String)
            .toList();
      }

      if (mounted) {
        setState(() {
          _cursos = cursosList;
          _profesores = profList;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al cargar profesores: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredProfesores = _profesores.where((p) {
        final matchesCurso = _selectedCursoId == null ||
            (p['curso_ids'] is List && (p['curso_ids'] as List).contains(_selectedCursoId));

        final nombre = (p['nombre_completo'] ?? '').toString().toLowerCase();
        final cedula = (p['cedula'] ?? '').toString().toLowerCase();
        final telefono = (p['telefono'] ?? '').toString().toLowerCase();

        final matchesQuery = query.isEmpty ||
            nombre.contains(query) ||
            cedula.contains(query) ||
            telefono.contains(query);

        return matchesCurso && matchesQuery;
      }).toList();
    });
  }

  Future<void> _showAddProfesorDialog() async {
    final nombreCtrl = TextEditingController();
    final cedulaCtrl = TextEditingController();
    final telfCtrl = TextEditingController();
    final correoCtrl = TextEditingController();
    String? selectedCursoId = _selectedCursoId;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Añadir Nuevo Profesor',
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
                      labelText: 'Nombre Completo *',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Cédula de Identidad * (Ej: V12345678)',
                      prefixIcon: Icon(Symbols.badge),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telfCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Symbols.call),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Correo Institucional / Personal',
                      prefixIcon: Icon(Symbols.mail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCursoId,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Asignar a Curso (Opcional)',
                      prefixIcon: Icon(Symbols.menu_book),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin curso asignado por ahora'),
                      ),
                      ..._cursos.map((c) {
                        return DropdownMenuItem<String?>(
                          value: c['id'] as String,
                          child: Text(c['nombre'] as String),
                        );
                      }),
                    ],
                    onChanged: (val) => setDialogState(() => selectedCursoId = val),
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
                  final cleanCedula = cedulaCtrl.text.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
                  final cleanEmail = correoCtrl.text.trim().isNotEmpty ? correoCtrl.text.trim() : null;

                  // 1. Insertar en perfiles
                  final inserted = await _supabase.from('perfiles').insert({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'email': cleanEmail,
                    'rol': 'profesor',
                  }).select().single();

                  final teacherId = inserted['id'] as String;

                  // 2. Sincronizar en tabla profesores
                  await _supabase.from('profesores').upsert({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'curso_sugerido': selectedCursoId != null
                        ? _cursos.firstWhere((c) => c['id'] == selectedCursoId)['nombre']
                        : null,
                  }, onConflict: 'cedula');

                  // 3. Asignar curso si se seleccionó
                  if (selectedCursoId != null) {
                    await _supabase
                        .from('cursos')
                        .update({'profesor_id': teacherId})
                        .eq('id', selectedCursoId!);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Profesor añadido con éxito.')),
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

  Future<void> _showEditProfesorDialog(Map<String, dynamic> prof) async {
    final nombreCtrl = TextEditingController(text: prof['nombre_completo'] ?? '');
    final cedulaCtrl = TextEditingController(text: prof['cedula'] ?? '');
    final telfCtrl = TextEditingController(text: prof['telefono'] ?? '');
    final correoCtrl = TextEditingController(text: prof['correo'] ?? prof['email'] ?? '');
    
    // Obtener curso actual si tiene
    final currentCourses = prof['curso_ids'] as List?;
    String? selectedCursoId = (currentCourses != null && currentCourses.isNotEmpty)
        ? currentCourses.first as String
        : null;

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Editar Profesor',
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
                      labelText: 'Nombre Completo *',
                      prefixIcon: Icon(Symbols.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: cedulaCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Cédula de Identidad *',
                      prefixIcon: Icon(Symbols.badge),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: telfCtrl,
                    keyboardType: TextInputType.phone,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Symbols.call),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: correoCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Correo Electrónico',
                      prefixIcon: Icon(Symbols.mail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: selectedCursoId,
                    dropdownColor: AppTheme.surfaceContainer,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Curso Asignado',
                      prefixIcon: Icon(Symbols.menu_book),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Sin curso asignado'),
                      ),
                      ..._cursos.map((c) {
                        return DropdownMenuItem<String?>(
                          value: c['id'] as String,
                          child: Text(c['nombre'] as String),
                        );
                      }),
                    ],
                    onChanged: (val) => setDialogState(() => selectedCursoId = val),
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
                  final cleanCedula = cedulaCtrl.text.trim().replaceAll(RegExp(r'[^0-9a-zA-Z]'), '');
                  final cleanEmail = correoCtrl.text.trim().isNotEmpty ? correoCtrl.text.trim() : null;
                  final profId = prof['id'] as String;

                  // 1. Actualizar perfiles
                  await _supabase.from('perfiles').update({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'email': cleanEmail,
                    'updated_at': DateTime.now().toIso8601String(),
                  }).eq('id', profId);

                  // 2. Actualizar o upsert en profesores
                  await _supabase.from('profesores').upsert({
                    'nombre_completo': nombreCtrl.text.trim(),
                    'cedula': cleanCedula,
                    'telefono': telfCtrl.text.trim().isNotEmpty ? telfCtrl.text.trim() : null,
                    'correo': cleanEmail,
                    'curso_sugerido': selectedCursoId != null
                        ? _cursos.firstWhere((c) => c['id'] == selectedCursoId)['nombre']
                        : null,
                    'updated_at': DateTime.now().toIso8601String(),
                  }, onConflict: 'cedula');

                  // 3. Gestionar asignación de curso
                  // Desasignar cualquier curso previo
                  await _supabase
                      .from('cursos')
                      .update({'profesor_id': null})
                      .eq('profesor_id', profId);

                  // Asignar el nuevo curso seleccionado si aplica
                  if (selectedCursoId != null) {
                    await _supabase
                        .from('cursos')
                        .update({'profesor_id': profId})
                        .eq('id', selectedCursoId!);
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Cambios guardados con éxito.')),
                    );
                    _loadData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppTheme.errorRed),
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

  Future<void> _confirmDeleteProfesor(Map<String, dynamic> prof) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmar Eliminación', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.bold)),
        content: Text(
          '¿Estás seguro de que deseas eliminar al profesor "${prof['nombre_completo']}" (C.I. ${prof['cedula']})?\n\nSe desasignará de los cursos que tenga a su cargo.',
          style: const TextStyle(color: AppTheme.onSurface),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final profId = prof['id'] as String;
        // Desasignar de cursos
        await _supabase.from('cursos').update({'profesor_id': null}).eq('profesor_id', profId);

        // Eliminar de profesores y perfiles
        if (prof['cedula'] != null) {
          await _supabase.from('profesores').delete().eq('cedula', prof['cedula']);
        }
        await _supabase.from('perfiles').delete().eq('id', profId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profesor eliminado y cursos desasignados.')),
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
              'Gestión de Profesores',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: AppTheme.onSurface,
              ),
            ),
            Text(
              'Super Admin • Asignación de cursos, edición y registro docente',
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
                    // Selector de Curso con Filtro
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _selectedCursoId,
                        dropdownColor: AppTheme.surfaceContainer,
                        style: const TextStyle(color: AppTheme.onSurface),
                        decoration: const InputDecoration(
                          labelText: 'Filtrar por Curso Asignado',
                          prefixIcon: Icon(Symbols.filter_alt, size: 20),
                          isDense: true,
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Todos los Cursos'),
                          ),
                          ..._cursos.map((c) {
                            return DropdownMenuItem<String?>(
                              value: c['id'] as String,
                              child: Text(c['nombre'] as String),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          _selectedCursoId = val;
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Botón Añadir Profesor
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _showAddProfesorDialog,
                      icon: const Icon(Symbols.person_add, size: 20),
                      label: const Text('Añadir Profesor'),
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
                          hintText: 'Buscar por nombre, cédula o teléfono de profesor...',
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
                        'Total: ${_filteredProfesores.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Profesores
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
                    : _filteredProfesores.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Symbols.badge, size: 64, color: AppTheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  'No se encontraron profesores registrados con estos criterios.',
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
                            itemCount: _filteredProfesores.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final prof = _filteredProfesores[index];
                              final nombre = prof['nombre_completo'] ?? 'Sin Nombre';
                              final cedula = prof['cedula'] ?? 'Sin Cédula';
                              final telefono = prof['telefono'] ?? 'Sin Teléfono';
                              final correo = prof['correo'] ?? prof['email'] ?? 'Sin Correo';
                              final cursosAsignados = (prof['cursos_asignados'] as List?)?.cast<String>() ?? [];

                              return Card(
                                elevation: 0,
                                color: AppTheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: AppTheme.outlineVariant),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.tertiary.withAlpha(40),
                                        foregroundColor: AppTheme.tertiary,
                                        radius: 22,
                                        child: Text(
                                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'P',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nombre,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 15,
                                                color: AppTheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: [
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.badge, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(cedula, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.call, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(telefono, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Symbols.mail, size: 14, color: AppTheme.onSurfaceVariant),
                                                    const SizedBox(width: 4),
                                                    Text(correo, style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            cursosAsignados.isNotEmpty
                                                ? Wrap(
                                                    spacing: 6,
                                                    runSpacing: 4,
                                                    children: cursosAsignados.map((cName) {
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: AppTheme.primaryContainer.withAlpha(40),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text(
                                                          'Curso: $cName',
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: AppTheme.primary,
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(),
                                                  )
                                                : Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.outlineVariant.withAlpha(50),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      'Sin curso asignado',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme.outline,
                                                      ),
                                                    ),
                                                  ),
                                          ],
                                        ),
                                      ),
                                      // Botones de acción: Editar y Eliminar
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Symbols.edit, color: AppTheme.primary, size: 20),
                                            tooltip: 'Editar Profesor',
                                            onPressed: () => _showEditProfesorDialog(prof),
                                          ),
                                          IconButton(
                                            icon: const Icon(Symbols.delete, color: AppTheme.errorRed, size: 20),
                                            tooltip: 'Eliminar Profesor',
                                            onPressed: () => _confirmDeleteProfesor(prof),
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
