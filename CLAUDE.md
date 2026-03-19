# CLAUDE.md - DevAll Analytics SDK

## Projeto

SDK oficial de analytics do DevAll Tech para Flutter. Permite monitorar eventos, erros e comportamentos de aplicativos Flutter com facilidade.

- **Versao:** 0.0.5
- **Linguagem:** Dart 3.5.4+
- **Framework:** Flutter (>=1.17.0)
- **Licenca:** MIT
- **Pub.dev:** https://pub.dev/packages/devall_analytics
- **Repo:** https://github.com/DevAllTech/devall_analytics

## Estrutura

```
lib/
  devall_analytics.dart          # Barrel file (exporta tudo)
  enums.dart                     # DevAllEventType e DevAllEnvironment
  device_identity.dart           # Gerenciamento de deviceId (UUID + SharedPreferences)
  src/
    devall_analytics_core.dart   # Classe principal (init, trackEvent, flush, retry, batch)
    platform_info_stub.dart      # Stub para conditional import
    platform_info_io.dart        # Device info para plataformas nativas (dart:io)
    platform_info_web.dart       # Device info para Web
    offline_storage.dart         # Persistencia offline de eventos (SharedPreferences)
test/
  devall_analytics_test.dart     # Testes unitarios com mock HTTP
example/
  main.dart                      # Exemplo de uso
```

## Comandos

```bash
flutter pub get          # Instalar dependencias
flutter analyze          # Rodar linter
flutter test             # Rodar testes
flutter pub publish      # Publicar no pub.dev
```

## Dependencias Principais

- `http: ^1.4.0` - Cliente HTTP para envio de eventos (+ `http/testing.dart` para mock)
- `shared_preferences: ^2.5.3` - Persistencia local do deviceId
- `uuid: ^4.5.1` - Geracao de UUID para identificacao do dispositivo
- `flutter_lints: ^4.0.0` - Regras de lint

## Arquitetura

- **DevAllAnalytics** (`lib/src/devall_analytics_core.dart`) - Classe estatica com:
  - `init()` - Inicializa com token, URL, client, e config de batch
  - `trackEvent()` - Envia ou enfileira eventos
  - `flush()` - Forca envio de eventos na fila (batch mode)
  - `reset()` - Reseta estado (para testes)
  - `retryOfflineEvents()` - Reenvia eventos salvos offline
  - `offlinePendingCount` - Numero de eventos na fila offline
  - `clearOfflineEvents()` - Limpa fila offline
  - Retry automatico com backoff exponencial (ate 3 tentativas em 5xx)
  - Fila offline persistente com retry periodico (SharedPreferences)
  - Envia via POST para `{baseUrl}/events`
- **DevAllOfflineStorage** (`lib/src/offline_storage.dart`) - Persistencia local de eventos que falharam no envio
- **DevAllDeviceIdentity** (`lib/device_identity.dart`) - Gera e persiste UUID do dispositivo via SharedPreferences
- **Platform Info** (`lib/src/platform_info_*.dart`) - Conditional imports para compatibilidade Web/IO
- **Enums** (`lib/enums.dart`) - `DevAllEventType` (error, warning, info, log, metric, custom) e `DevAllEnvironment` (dev, staging, prod)

## Convencoes

- Codigo em Dart com null-safety
- Linting via `flutter_lints`
- Prefixo `DevAll` em todas as classes publicas
- Logs de debug via `kDebugMode` (nao polui release)
- Commits seguem conventional commits com emojis (ex: :sparkles:, :recycle:, :tada:)
- Testes usam `MockClient` do package `http/testing.dart`
- Codigo interno fica em `lib/src/` (nao exportado diretamente)

## API Endpoint

- **POST** `{baseUrl}/events` (default: `https://api-logs.devalltech.com.br/api/v1/events`)
- Header: `x-project-token` com o token do projeto
- Body (single): JSON com deviceId, timestamp, type, environment, category, message, payload, deviceInfo, ip
- Body (batch): `{"events": [...]}`

## Plataformas Suportadas

Android, iOS, Web, macOS, Windows, Linux
