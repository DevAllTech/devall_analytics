# 📊 devall_analytics

**SDK oficial do DevAll Tech Analytics para Flutter.**  
Monitore eventos, erros e comportamentos do seu aplicativo com facilidade.

[![pub package](https://img.shields.io/pub/v/devall_analytics.svg)](https://pub.dev/packages/devall_analytics)

---

## ✨ Recursos

- ✅ Envio de eventos categorizados (error, warning, info, custom, etc)
- ✅ Registro de payloads personalizados
- ✅ Suporte a múltiplos ambientes (dev, staging, prod)
- ✅ Captura automática de informações básicas do dispositivo
- ✅ Leve e sem dependências externas

---

## 🚀 Instalação

Adicione ao seu `pubspec.yaml`:

```yaml
dependencies:
  devall_analytics: ^0.0.3
```

Rode:

```bash
flutter pub get
```

---

## 🛠️ Como usar

### 1. Inicialize com o token do seu projeto:

```dart
DevAllAnalytics.init(projectToken: 'SUA_CHAVE_DO_PROJETO');
```

### 2. Envie um evento:

```dart
await DevAllAnalytics.trackEvent(
  type: DevAllEventType.error,
  environment: DevAllEnvironment.dev,
  category: 'Login',
  message: 'Erro ao autenticar usuário',
  payload: {
    'email': 'teste@exemplo.com',
    'erro': 'senha inválida',
  },
  // Opcional: coleta padrão se não for informado
  deviceInfo: await DevAllAnalytics.getDefaultDeviceInfo(),
);
```

---

## 🎯 Tipos de evento

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

## 🌐 Ambientes

```dart
enum DevAllEnvironment {
  dev,
  staging,
  prod,
}
```

---

## 🔍 Exemplo completo

Veja na pasta [`example/`](example/main.dart) um projeto de exemplo com o SDK em funcionamento.

---

## 📝 License

MIT License © [DevAll Tech](https://devalltech.com.br)

---

Feito com 💙 por DevAll Tech
