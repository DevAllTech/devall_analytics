## [0.0.3] - 2025-05-28

### Added

- Novo método auxiliar `getDefaultDeviceInfo()` que retorna informações básicas do dispositivo sem dependências externas:
  - `platform`, `osVersion`, `locale`, `isPhysicalDevice`
- Caso `deviceInfo` não seja informado em `trackEvent()`, o SDK utiliza automaticamente esse fallback interno.

### Changed

- Classe principal renomeada de `DevallAnalytics` para `DevAllAnalytics`
- `timestamp` agora pode ser informado por parâmetro. Se omitido, é gerado automaticamente com `DateTime.now()`
