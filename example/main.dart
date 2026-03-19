import 'package:devall_analytics/devall_analytics.dart';

void main() async {
  // Inicializa o SDK com seu token de projeto
  DevAllAnalytics.init(projectToken: 'seu-token-do-projeto');

  // Envia um evento de erro
  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.error,
    environment: DevAllEnvironment.dev,
    category: 'autenticacao',
    message: 'Falha ao fazer login',
    payload: {'errorCode': '401', 'description': 'Token invalido'},
  );

  // Envia um evento customizado
  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.custom,
    environment: DevAllEnvironment.prod,
    category: 'compra',
    message: 'Usuario finalizou compra com sucesso',
    payload: {'valor': 199.99, 'produtoId': 'abc123'},
  );

  // --- Modo batch (opcional) ---
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    enableBatch: true,
    batchSize: 5,
    flushInterval: Duration(seconds: 15),
  );

  // Eventos ficam em fila ate atingir batchSize ou flushInterval
  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.metric,
    environment: DevAllEnvironment.prod,
    category: 'performance',
    message: 'Tempo de carregamento da tela',
    payload: {'screen': 'home', 'loadTimeMs': 320},
  );

  // Forca envio manual dos eventos na fila
  await DevAllAnalytics.flush();

  // --- URL customizada (self-hosted) ---
  DevAllAnalytics.init(
    projectToken: 'seu-token',
    baseUrl: 'https://sua-api.example.com/v1',
  );
}
