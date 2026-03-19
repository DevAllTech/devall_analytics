## [0.1.0] - 2026-03-19

### Novidades

- **Compatibilidade Web**: corrigido uso de `dart:io` que quebrava na Web. Agora usa conditional imports para funcionar em todas as plataformas.
- **Retry com backoff**: falhas de rede (5xx) sao retentadas automaticamente ate 3 vezes com backoff exponencial.
- **Modo batch**: novo sistema de envio agrupado de eventos (`enableBatch`, `batchSize`, `flushInterval`, `flush()`).
- **URL configuravel**: parametro `baseUrl` no `init()` para ambientes self-hosted ou staging.
- **HTTP client injetavel**: parametro `httpClient` no `init()` para facilitar testes com mock.
- **Barrel file**: import unico via `package:devall_analytics/devall_analytics.dart` exporta tudo.
- **Modo offline**: eventos que falham no envio sao salvos localmente (SharedPreferences) e reenviados automaticamente quando a internet volta.
  - `enableOffline` (default: true) - ativa/desativa a fila offline
  - `offlineRetryInterval` (default: 2min) - intervalo de retry automatico
  - `maxOfflineEvents` (default: 500) - limite maximo de eventos offline
  - `retryOfflineEvents()` - metodo publico para trigger manual (ex: ao detectar mudanca de conectividade)
  - `offlinePendingCount` - consulta quantos eventos estao na fila
  - `clearOfflineEvents()` - limpa a fila offline

### Correcoes

- Validacao de token vazio (antes so validava `null`, agora tambem rejeita strings vazias).
- Campo `isPhysicalDevice` agora retorna valor correto por plataforma (antes usava `!kIsWeb` que era impreciso).
- Campo `ip` omitido do payload quando nulo (antes enviava `"ip": null`).

### Refatoracoes

- `getDefaultDeviceInfo()` agora e privado (detalhe de implementacao).
- Adicionado `reset()` para facilitar testes.
- Codigo movido para `lib/src/` seguindo convencoes do Dart.
- Testes reescritos com mock HTTP e cobertura real de payload, retry, batch e validacao.

---

## [0.0.4] - 2025-06-03

### Novidades

- Adicionado suporte interno a `deviceId` (UUID gerado localmente), permitindo rastrear a origem dos eventos por instalacao.
- Preparacao para futuras melhorias com suporte a identificacao por usuario (e-mail e nome).

### Refatoracoes

- Codigo mais limpo com tratamento padrao para campos opcionais como `timestamp` e `deviceInfo`.
- Agora, se `timestamp` nao for informado, sera atribuido automaticamente o horario atual.
- Se `deviceInfo` for omitido, e enviado como objeto padrao.
