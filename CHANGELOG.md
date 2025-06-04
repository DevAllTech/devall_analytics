## [0.0.4] - 2025-06-03

### ✨ Novidades

- Adicionado suporte interno a `deviceId` (UUID gerado localmente), permitindo rastrear a origem dos eventos por instalação.
- Preparação para futuras melhorias com suporte a identificação por usuário (e-mail e nome).

### 🧼 Refatorações

- Código mais limpo com tratamento padrão para campos opcionais como `timestamp` e `deviceInfo`.
- Agora, se `timestamp` não for informado, será atribuído automaticamente o horário atual.
- Se `deviceInfo` for omitido, é enviado como objeto padrão `{ 'platform': '', 'osVersion': '', 'locale': '', 'isPhysicalDevice': true }`.

---

### ✅ Exemplo de uso

```dart
await DevAllAnalytics.trackEvent(
  type: DevAllEventType.warning,
  environment: DevAllEnvironment.staging,
  category: "Onboarding",
  message: "Tela travada ao carregar passo 2",
  payload: {"step": 2},
);
```
