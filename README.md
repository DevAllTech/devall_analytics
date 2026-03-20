# devall_analytics

**SDK oficial do DevAll Tech Analytics para Flutter.**
Monitore eventos, erros e comportamentos do seu aplicativo com facilidade.

[![pub package](https://img.shields.io/pub/v/devall_analytics.svg)](https://pub.dev/packages/devall_analytics)
![Publisher](https://img.shields.io/badge/publisher-devalltech.com.br-blue)
[![license](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## Recursos

- Envio de eventos categorizados (error, warning, info, log, metric, custom)
- Registro de payloads personalizados
- Suporte a multiplos ambientes (dev, staging, prod)
- Captura automatica de informacoes do dispositivo
- Compativel com todas as plataformas Flutter (Android, iOS, Web, macOS, Windows, Linux)
- Retry automatico com backoff exponencial em falhas de rede
- Modo batch para envio agrupado de eventos
- URL da API configuravel (self-hosted)
- HTTP client injetavel para facilitar testes
- Leve e com dependencias minimas

---

## Instalacao

Adicione ao seu `pubspec.yaml`:

```yaml
dependencies:
  devall_analytics: ^0.1.1
```

Rode:

```bash
flutter pub get
```

---

## Como usar

### 1. Import unico

```dart
import 'package:devall_analytics/devall_analytics.dart';
```

Todas as classes e enums sao exportados automaticamente.

### 2. Inicialize com o token do seu projeto

```dart
DevAllAnalytics.init(projectToken: 'SUA_CHAVE_DO_PROJETO');
```

### 3. Envie um evento

```dart
await DevAllAnalytics.trackEvent(
  type: DevAllEventType.error,
  environment: DevAllEnvironment.dev,
  category: 'Login',
  message: 'Erro ao autenticar usuario',
  payload: {
    'email': 'teste@exemplo.com',
    'erro': 'senha invalida',
  },
);
```

O `deviceInfo` e `timestamp` sao preenchidos automaticamente se nao fornecidos.

---

## Configuracoes avancadas

### URL customizada (self-hosted)

```dart
DevAllAnalytics.init(
  projectToken: 'SUA_CHAVE',
  baseUrl: 'https://sua-api.example.com/v1',
);
```

### Modo batch

Acumula eventos e envia em lote para reduzir chamadas de rede:

```dart
DevAllAnalytics.init(
  projectToken: 'SUA_CHAVE',
  enableBatch: true,
  batchSize: 10,           // envia a cada 10 eventos
  flushInterval: Duration(seconds: 30), // ou a cada 30s
);

// Forca envio manual
await DevAllAnalytics.flush();
```

### Modo offline (auto-retry)

Eventos que falham no envio sao salvos localmente e reenviados automaticamente:

```dart
DevAllAnalytics.init(
  projectToken: 'SUA_CHAVE',
  enableOffline: true,              // default: true
  offlineRetryInterval: Duration(minutes: 2), // default: 2min
  maxOfflineEvents: 500,            // default: 500
);

// Ver quantos eventos estao na fila offline
final pending = await DevAllAnalytics.offlinePendingCount;
print('Eventos pendentes: $pending');

// Forcar retry manual (ex: ao detectar que o Wi-Fi voltou)
await DevAllAnalytics.retryOfflineEvents();

// Limpar fila offline
await DevAllAnalytics.clearOfflineEvents();
```

O SDK tenta automaticamente reenviar eventos offline:
- Na inicializacao (`init()`)
- Periodicamente (a cada `offlineRetryInterval`)
- Manualmente via `retryOfflineEvents()`

Eventos com erro 4xx (dados invalidos) **nao** sao salvos offline — apenas falhas de rede e erros de servidor (5xx).

### HTTP client customizado (testes)

```dart
import 'package:http/testing.dart';

final mockClient = MockClient((request) async {
  return http.Response('ok', 200);
});

DevAllAnalytics.init(
  projectToken: 'test-token',
  httpClient: mockClient,
);
```

---

## Tipos de evento

```dart
enum DevAllEventType {
  error,
  warning,
  info,
  log,
  metric,
  custom,
}
```

## Ambientes

```dart
enum DevAllEnvironment {
  dev,
  staging,
  prod,
}
```

---

## Exemplo completo

Veja na pasta [`example/`](example/main.dart) um projeto de exemplo com o SDK em funcionamento.

---

## Publicado por [DevAll Tech](https://pub.dev/publishers/devalltech.com.br/packages)

Este pacote e mantido oficialmente pela equipe da DevAll Tech.
Veja todos os pacotes em [`nossa pagina de publicadores no pub.dev`](https://pub.dev/publishers/devalltech.com.br/packages).

---

## License

MIT License - [DevAll Tech](https://devalltech.com.br)
