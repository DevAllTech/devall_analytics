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

  // --- Modo offline (habilitado por padrao) ---
  // Se o envio falhar (sem internet, servidor fora), eventos sao salvos
  // localmente e reenviados automaticamente quando a conexao voltar.
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    enableOffline: true,                         // default: true
    offlineRetryInterval: Duration(minutes: 2),  // default: 2min
    maxOfflineEvents: 500,                       // default: 500
  );

  // Ver quantos eventos estao na fila offline
  final pending = await DevAllAnalytics.offlinePendingCount;
  print('Eventos pendentes offline: $pending');

  // Forcar reenvio manual (ex: app detectou que o Wi-Fi voltou)
  await DevAllAnalytics.retryOfflineEvents();

  // Limpar fila offline
  await DevAllAnalytics.clearOfflineEvents();

  // --- URL customizada (self-hosted) ---
  DevAllAnalytics.init(
    projectToken: 'seu-token',
    baseUrl: 'https://sua-api.example.com/v1',
  );
}
