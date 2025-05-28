import 'package:devall_analytics/enums.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:devall_analytics/devall_analytics.dart';

void main() {
  group('DevallAnalytics', () {
    setUp(() {
      DevAllAnalytics.init(projectToken: 'fake-token');
    });

    test('trackEvent should not throw exception when properly initialized',
        () async {
      expect(
        () => DevAllAnalytics.trackEvent(
          type: DevAllEventType.log,
          environment: DevAllEnvironment.dev,
          category: 'teste',
          message: 'Evento de teste',
          payload: {'campo': 'valor'},
          deviceInfo: {'platform': 'web', 'version': '1.0'},
        ),
        returnsNormally,
      );
    });

    test('throws exception if trackEvent is called without init', () async {
      // Reset token manualmente para simular o erro
      DevAllAnalytics.init(projectToken: '');
      expect(
        () => DevAllAnalytics.trackEvent(
          type: DevAllEventType.log,
          environment: DevAllEnvironment.dev,
          category: 'falha',
          message: 'Teste sem init válido',
          payload: {},
          deviceInfo: {},
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
