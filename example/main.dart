import 'package:devall_analytics/devall_analytics.dart';
import 'package:devall_analytics/enums.dart';

void main() {
  // Inicializa o SDK com seu token de projeto
  DevAllAnalytics.init(projectToken: 'seu-token-do-projeto');

  // Envia um evento de erro
  DevAllAnalytics.trackEvent(
    type: DevAllEventType.error,
    environment: DevAllEnvironment.dev,
    category: 'autenticacao',
    message: 'Falha ao fazer login',
    payload: {'errorCode': '401', 'description': 'Token inválido'},
    deviceInfo: {
      'platform': 'android',
      'appVersion': '1.0.0',
      'deviceModel': 'Pixel 5'
    },
  );

  // Envia um evento customizado
  DevAllAnalytics.trackEvent(
    type: DevAllEventType.custom,
    environment: DevAllEnvironment.prod,
    category: 'compra',
    message: 'Usuário finalizou compra com sucesso',
    payload: {'valor': 199.99, 'produtoId': 'abc123'},
    deviceInfo: {
      'platform': 'ios',
      'appVersion': '2.3.1',
      'deviceModel': 'iPhone 13'
    },
  );
}
