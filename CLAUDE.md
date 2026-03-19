# CLAUDE.md - DevAll Analytics SDK

## Projeto

SDK oficial de analytics do DevAll Tech para Flutter. Permite monitorar eventos, erros e comportamentos de aplicativos Flutter com facilidade.

- **Versao:** 0.0.4
- **Linguagem:** Dart 3.5.4+
- **Framework:** Flutter (>=1.17.0)
- **Licenca:** MIT
- **Pub.dev:** https://pub.dev/packages/devall_analytics
- **Repo:** https://github.com/DevAllTech/devall_analytics

## Estrutura

```
lib/
  devall_analytics.dart    # Classe principal (init + trackEvent)
  device_identity.dart     # Gerenciamento de deviceId (UUID + SharedPreferences)
  enums.dart               # DevAllEventType e DevAllEnvironment
test/
  devall_analytics_test.dart  # Testes unitarios
example/
  main.dart                # Exemplo de uso
```

## Comandos

```bash
flutter pub get          # Instalar dependencias
flutter analyze          # Rodar linter
flutter test             # Rodar testes
flutter pub publish      # Publicar no pub.dev
```

## Dependencias Principais

- `http: ^1.4.0` - Cliente HTTP para envio de eventos
- `shared_preferences: ^2.5.3` - Persistencia local do deviceId
- `uuid: ^4.5.1` - Geracao de UUID para identificacao do dispositivo
- `flutter_lints: ^4.0.0` - Regras de lint

## Arquitetura

- **DevAllAnalytics** - Classe estatica com `init()` e `trackEvent()`. Envia eventos via POST para `https://api-logs.devalltech.com.br/api/v1/events`
- **DevAllDeviceIdentity** - Gera e persiste UUID do dispositivo via SharedPreferences
- **Enums** - `DevAllEventType` (error, warning, info, log, metric, custom) e `DevAllEnvironment` (dev, staging, prod)

## Convencoes

- Codigo em Dart com null-safety
- Linting via `flutter_lints`
- Prefixo `DevAll` em todas as classes publicas
- Logs de debug via `kDebugMode` (nao polui release)
- Commits seguem conventional commits com emojis (ex: :sparkles:, :recycle:, :tada:)

## API Endpoint

- **POST** `https://api-logs.devalltech.com.br/api/v1/events`
- Header: `x-project-token` com o token do projeto
- Body: JSON com deviceId, timestamp, type, environment, category, message, payload, deviceInfo, ip

## Plataformas Suportadas

Android, iOS, Web, macOS, Windows, Linux
