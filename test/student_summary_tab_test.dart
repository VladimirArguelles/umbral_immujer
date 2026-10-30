import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/features/student/presentation/student_summary_tab.dart';

void main() {
  testWidgets('shows formation carousel and summary modules', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudentSummaryTab(
            studentName: 'María',
            onNavigate: _ignoreNavigation,
          ),
        ),
      ),
    );

    expect(find.text('Hola, María'), findsOneWidget);
    expect(find.text('FORMACIONES IMMUJER'), findsOneWidget);
    expect(find.text('Diseño y Estética de Cejas'), findsOneWidget);
    expect(find.text('MIS CURSOS'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-320, 0));
    await tester.pumpAndSettle();
    expect(find.text('Panadería y Masas Artesanales'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(find.text('ENCUESTAS Y APORTES'), findsOneWidget);
  });

  testWidgets('module buttons select their corresponding dashboard tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final selectedTabs = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentSummaryTab(
            studentName: 'María',
            onNavigate: selectedTabs.add,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('IR A MI ASISTENCIA'));
    await tester.tap(find.text('IR A MI ASISTENCIA'));
    await tester.pump();

    expect(selectedTabs, [2]);
  });
}

void _ignoreNavigation(int _) {}
