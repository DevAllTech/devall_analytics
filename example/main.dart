import 'package:devall_analytics/devall_analytics.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ─── Inicializacao basica ───
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    samplingRate: 1.0, // Envia 100% dos eventos (default)
    maxEventsPerMinute: 60, // Limite de 60 eventos/min
    maxBreadcrumbs: 50, // Maximo de 50 breadcrumbs
  );

  // ─── Identificacao de usuario ───
  DevAllAnalytics.identify(
    userId: 'user-123',
    traits: {
      'email': 'usuario@exemplo.com',
      'name': 'Joao Silva',
      'plan': 'premium',
    },
  );
  // Todos os eventos agora incluem userId e traits

  // Ao fazer logout:
  // DevAllAnalytics.clearIdentity();

  // ─── Session tracking ───
  final sessionId = DevAllAnalytics.startSession();
  print('Session iniciada: $sessionId');
  // Eventos incluem sessionId automaticamente

  // ─── Captura automatica de erros ───
  DevAllAnalytics.captureFlutterErrors();
  // Agora FlutterError.onError e PlatformDispatcher.onError
  // enviam eventos automaticamente

  // ─── Lifecycle tracking ───
  DevAllAnalytics.enableLifecycleTracking();
  // Rastreia automaticamente: app_open, app_resumed, app_paused, app_detached
  // Tambem gerencia sessoes automaticamente (inicia/encerra com lifecycle)

  // ─── Screen tracking ───
  DevAllAnalytics.trackScreen('HomePage');
  // Ao mudar de tela:
  DevAllAnalytics.trackScreen('ProfilePage');
  // A tela anterior e encerrada automaticamente com duracao

  // ─── Breadcrumbs ───
  DevAllAnalytics.addBreadcrumb(
    category: 'ui',
    message: 'Clicou no botao "Comprar"',
    data: {'button_id': 'buy_now'},
  );
  DevAllAnalytics.addBreadcrumb(
    category: 'api',
    message: 'POST /api/orders',
    data: {'status': 200},
  );
  // Breadcrumbs sao incluidos automaticamente em eventos de erro

  // ─── Middleware (onBeforeSend) ───
  // Redact dados sensiveis antes de enviar
  DevAllAnalytics.addMiddleware((event) {
    final payload = event['payload'] as Map<String, dynamic>?;
    if (payload != null) {
      payload.remove('password');
      payload.remove('creditCard');
      if (payload.containsKey('email')) {
        payload['email'] = '***@***.com';
      }
    }
    return event;
  });

  // Bloquear eventos de uma categoria especifica
  DevAllAnalytics.addMiddleware((event) {
    if (event['category'] == 'debug_only' &&
        event['environment'] == 'prod') {
      return null; // Bloqueia o evento
    }
    return event;
  });

  // ─── Consent/GDPR ───
  // O padrao e opt-out (tracking ativado ate o usuario revogar)
  await DevAllAnalytics.setConsent(granted: true);
  // Para revogar: await DevAllAnalytics.setConsent(granted: false);
  // Quando revogado, todos os eventos sao silenciosamente descartados

  // ─── Multi-destination (forwarding) ───
  // Encaminhar eventos para outros servicos
  DevAllAnalytics.addDestination(ConsoleLogDestination());
  // Crie suas proprias implementacoes de DevAllEventDestination
  // para Sentry, Firebase, Mixpanel, etc.

  // ─── Enviar eventos normalmente ───
  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.error,
    environment: DevAllEnvironment.dev,
    category: 'autenticacao',
    message: 'Falha ao fazer login',
    payload: {'errorCode': '401', 'description': 'Token invalido'},
  );

  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.custom,
    environment: DevAllEnvironment.prod,
    category: 'compra',
    message: 'Usuario finalizou compra com sucesso',
    payload: {'valor': 199.99, 'produtoId': 'abc123'},
  );

  // ─── Modo batch (opcional) ───
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    enableBatch: true,
    batchSize: 5,
    flushInterval: Duration(seconds: 15),
  );

  await DevAllAnalytics.trackEvent(
    type: DevAllEventType.metric,
    environment: DevAllEnvironment.prod,
    category: 'performance',
    message: 'Tempo de carregamento da tela',
    payload: {'screen': 'home', 'loadTimeMs': 320},
  );

  // Forca envio manual dos eventos na fila
  await DevAllAnalytics.flush();

  // ─── Modo offline (habilitado por padrao) ───
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    enableOffline: true,
    offlineRetryInterval: Duration(minutes: 2),
    maxOfflineEvents: 500,
  );

  final pending = await DevAllAnalytics.offlinePendingCount;
  print('Eventos pendentes offline: $pending');

  await DevAllAnalytics.retryOfflineEvents();
  await DevAllAnalytics.clearOfflineEvents();

  // ─── Debug overlay (apenas em modo debug) ───
  // Adicione o widget DevAllDebugOverlay em um Stack:
  // Stack(children: [
  //   MyApp(),
  //   DevAllDebugOverlay(), // Mostra eventos em tempo real
  // ])

  // ─── Sampling rate ───
  // Enviar apenas 10% dos eventos (util para apps com milhoes de usuarios)
  DevAllAnalytics.init(
    projectToken: 'seu-token-do-projeto',
    samplingRate: 0.1,
  );
}

/// Exemplo de destino customizado que loga no console.
class ConsoleLogDestination implements DevAllEventDestination {
  @override
  String get name => 'ConsoleLog';

  @override
  Future<void> sendEvent(Map<String, dynamic> event) async {
    print('[ConsoleLog] ${event['type']}: ${event['message']}');
  }
}
