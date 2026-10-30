import 'package:flutter_test/flutter_test.dart';
import 'package:umbral_immujer/features/student/domain/student_models.dart';

void main() {
  group('StudentSurvey tests', () {
    test('cuotaACancelar prioritizes montoAsignado over montoIndividual', () {
      final survey = StudentSurvey(
        id: 'survey-1',
        cursoId: 'curso-1',
        cursoNombre: 'Confección Textil',
        fechaClase: '2026-11-05',
        costoTotalInsumos: 100.0,
        fechaLimite: DateTime.now().add(const Duration(days: 2)),
        montoIndividual: 20.0,
        totalConfirmados: 5,
        estadoEncuesta: 'activa',
        montoAsignado: 25.0,
      );

      expect(survey.cuotaACancelar, 25.0);
    });

    test('cuotaACancelar falls back to montoIndividual if montoAsignado is null or 0', () {
      final survey = StudentSurvey(
        id: 'survey-2',
        cursoId: 'curso-1',
        cursoNombre: 'Confección Textil',
        fechaClase: '2026-11-05',
        costoTotalInsumos: 100.0,
        fechaLimite: DateTime.now().add(const Duration(days: 2)),
        montoIndividual: 20.0,
        totalConfirmados: 5,
        estadoEncuesta: 'activa',
        montoAsignado: null,
      );

      expect(survey.cuotaACancelar, 20.0);
    });

    test('estaVencida returns true when current date is past fechaLimite', () {
      final pastSurvey = StudentSurvey(
        id: 'survey-past',
        cursoId: 'curso-1',
        cursoNombre: 'Repostería',
        fechaClase: '2026-10-01',
        costoTotalInsumos: 80.0,
        fechaLimite: DateTime.now().subtract(const Duration(days: 1)),
        montoIndividual: 16.0,
        totalConfirmados: 5,
        estadoEncuesta: 'cerrada',
      );

      expect(pastSurvey.estaVencida, isTrue);
    });

    test('tieneCapturePendiente returns true when student will attend without proof', () {
      final survey = StudentSurvey(
        id: 'survey-3',
        cursoId: 'curso-1',
        cursoNombre: 'Pastelería',
        fechaClase: '2026-11-02',
        costoTotalInsumos: 60.0,
        fechaLimite: DateTime.now().add(const Duration(days: 1)),
        montoIndividual: 15.0,
        totalConfirmados: 4,
        estadoEncuesta: 'activa',
        respondio: true,
        asistira: true,
        comprobanteUrl: null,
      );

      expect(survey.tieneCapturePendiente, isTrue);
    });
  });

  group('StudentPaymentRecord tests', () {
    test('verifies state helpers correctly', () {
      final verificado = StudentPaymentRecord(
        id: 'p-1',
        encuestaId: 'e-1',
        cursoId: 'c-1',
        cursoNombre: 'Diseño Web',
        fechaClase: '2026-11-10',
        montoCancelado: 25.0,
        comprobanteUrl: 'https://example.com/voucher.jpg',
        estadoPago: 'verificado',
        asistira: true,
      );

      expect(verificado.isVerificado, isTrue);
      expect(verificado.isPendiente, isFalse);
      expect(verificado.isRechazado, isFalse);

      final pendiente = StudentPaymentRecord(
        id: 'p-2',
        encuestaId: 'e-2',
        cursoId: 'c-1',
        cursoNombre: 'Diseño Web',
        fechaClase: '2026-11-17',
        montoCancelado: 25.0,
        comprobanteUrl: 'https://example.com/voucher2.jpg',
        estadoPago: 'pendiente',
        asistira: true,
      );

      expect(pendiente.isVerificado, isFalse);
      expect(pendiente.isPendiente, isTrue);
      expect(pendiente.isRechazado, isFalse);

      final rechazado = StudentPaymentRecord(
        id: 'p-3',
        encuestaId: 'e-3',
        cursoId: 'c-1',
        cursoNombre: 'Diseño Web',
        fechaClase: '2026-11-24',
        montoCancelado: 25.0,
        comprobanteUrl: 'https://example.com/voucher3.jpg',
        estadoPago: 'rechazado',
        asistira: true,
      );

      expect(rechazado.isVerificado, isFalse);
      expect(rechazado.isPendiente, isFalse);
      expect(rechazado.isRechazado, isTrue);
    });
  });
}
