# Техническое задание: LimitBar

> Исторический baseline-документ. Текущая реализация ушла от `Accessibility-first` подхода к `local-auth/session-first` архитектуре.
> Актуальное архитектурное решение зафиксировано в `docs/adr/2026-04-07-local-auth-session-first-architecture.md`.
> Актуальный продуктовый spec находится в `docs/current-product-spec.md`.

## 1. Название проекта
**LimitBar**

## 2. Краткое описание
LimitBar — это macOS menu bar приложение для отслеживания лимитов, времени восстановления и статуса подписок по нескольким аккаунтам AI coding tools, начиная с Codex и с возможностью дальнейшего добавления Claude.

## 3. Цель продукта
Упростить работу пользователей, которые используют несколько аккаунтов в AI coding tools и переключаются между ними из-за лимитов, cooldown-периодов и окончания подписок.

Приложение должно помогать быстро понять:
- какой аккаунт доступен прямо сейчас;
- у какого аккаунта лимит скоро восстановится;
- у какого аккаунта скоро закончится подписка;
- какой аккаунт лучше использовать следующим.

---

## 4. Основная проблема
Пользователь работает через несколько аккаунтов в Codex и аналогичных AI-инструментах.  
Когда лимиты заканчиваются, он переключается между аккаунтами.  
Основная боль:
- невозможно быстро вспомнить, где именно лимит уже выбит;
- непонятно, когда какой аккаунт снова станет доступен;
- легко забыть, на каком аккаунте скоро закончится подписка;
- возникает хаос при переключении между аккаунтами.

---

## 5. Основной сценарий использования
1. Пользователь открывает Codex app.
2. LimitBar определяет активный аккаунт.
3. Приложение считывает usage / cooldown / reset info из интерфейса Codex app.
4. Для каждого аккаунта отображаются:
   - e-mail или label;
   - статус;
   - daily / weekly usage (если доступно);
   - время до восстановления;
   - дата окончания подписки (если доступно).
5. Пользователь смотрит на menu bar и сразу понимает, какой аккаунт использовать.

---

## 6. Платформа
- **ОС:** macOS
- **Формат:** menu bar utility
- **Основной стек:** Swift + SwiftUI
- **UI-фреймворк:** `MenuBarExtra`
- **Системные API:** Accessibility API
- **Уведомления:** UNUserNotificationCenter

---

## 7. Принцип работы
Приложение **не должно**:
- парсить сайт ChatGPT;
- читать Gmail или другую почту;
- требовать браузер;
- перехватывать внутренние API-запросы;
- читать содержимое чатов, задач или проектов;
- автоматически кликать по элементам интерфейса Codex app.

Приложение должно работать как **read-only companion app**:
- находить Codex app;
- читать его окно через Accessibility;
- извлекать usage / reset / subscription data;
- сохранять это локально;
- показывать агрегированную картину по аккаунтам в верхнем меню.

---

## 8. Поддерживаемые провайдеры
### На старте:
- Codex

### В будущем:
- Claude

Архитектура должна быть сразу спроектирована как provider-agnostic, чтобы не привязывать приложение только к одному сервису.

---

## 9. Основные сущности
### 9.1 Provider
AI-сервис, например:
- Codex
- Claude

### 9.2 Account
Аккаунт внутри провайдера:
- e-mail
- label
- provider
- статус
- приоритет
- заметка

### 9.3 Usage Snapshot
Состояние аккаунта на момент последнего считывания:
- daily usage
- weekly usage
- next reset time
- subscription expiry date
- source confidence
- last synced time

---

## 10. Функциональные требования V1

### 10.1 Отслеживание нескольких аккаунтов
Приложение должно уметь:
- хранить несколько аккаунтов;
- связывать usage-данные с конкретным аккаунтом;
- отображать список всех известных аккаунтов.

### 10.2 Определение активного аккаунта
Приложение должно пытаться определить:
- e-mail активного аккаунта;
- либо другой уникальный label, если e-mail недоступен.

### 10.3 Считывание usage-данных
Приложение должно считывать:
- daily usage percentage, если доступно;
- weekly usage percentage, если доступно;
- текстовый статус лимита;
- reset / cooldown info;
- last sync timestamp.

### 10.4 Отображение статуса аккаунта
Статусы:
- `available`
- `coolingDown`
- `exhausted`
- `unknown`
- `stale`

### 10.5 Countdown до восстановления
Если найдено время восстановления:
- показывать countdown;
- хранить next reset datetime;
- обновлять таймер в интерфейсе.

### 10.6 Menu bar интерфейс
В верхнем меню должно отображаться:
- иконка приложения;
- короткий индикатор состояния.

В раскрывающемся меню:
- текущий активный аккаунт;
- список всех аккаунтов;
- статус, usage и reset info по каждому аккаунту;
- кнопка `Refresh now`;
- кнопка `Open Codex`;
- кнопка `Settings`;
- кнопка `Quit`.

### 10.7 Уведомления
Приложение должно уметь отправлять локальные уведомления:
- когда cooldown заканчивается;
- когда аккаунт снова должен стать доступен;
- когда подписка скоро истекает (во V2).

---

## 11. Функциональные требования V2

### 11.1 Отслеживание подписки
Для каждого аккаунта:
- дата окончания подписки;
- статус подписки:
  - `active`
  - `expiringSoon`
  - `expired`

### 11.2 Напоминания о продлении
Уведомления:
- за 7 дней;
- за 3 дня;
- за 1 день;
- в день окончания.

### 11.3 Приоритеты аккаунтов
Возможность назначать:
- основной аккаунт;
- резервный аккаунт;
- вспомогательный аккаунт.

### 11.4 Заметки
Пользователь может добавить заметку:
- `основной`
- `резервный`
- `только Codex`
- `дорогой`
- любая произвольная заметка

---

## 12. Функциональные требования V3

### 12.1 Поддержка Claude
Добавить второго провайдера:
- Claude

### 12.2 Единый multi-provider список
Показывать все аккаунты в одном списке с фильтрацией:
- All
- Codex
- Claude

### 12.3 Интеллектуальные подсказки
Возможные подсказки:
- какой аккаунт лучше использовать сейчас;
- какой аккаунт восстановится раньше;
- какой аккаунт не стоит трогать до вечера;
- какой аккаунт скоро выпадет из работы из-за подписки.

---

## 13. Нефункциональные требования

### 13.1 Производительность
- приложение не должно заметно нагружать систему;
- polling должен быть адаптивным;
- при закрытом Codex app частота опроса должна снижаться.

### 13.2 Безопасность
Приложение не должно хранить:
- пароли;
- токены авторизации;
- содержимое чатов;
- код проектов;
- чувствительные данные, не относящиеся к usage/account status.

### 13.3 Приватность
Локально можно сохранять только:
- e-mail / label аккаунта;
- usage summary;
- timestamps;
- subscription expiry;
- локальные заметки пользователя.

### 13.4 Отказоустойчивость
Если приложение не может считать usage:
- оно не должно падать;
- оно должно показывать `No usage data found`;
- оно должно предлагать открыть нужный экран в Codex app.

---

## 14. Источник данных

### 14.1 Основной источник
**Accessibility API**

Приложение должно:
- находить окно Codex app;
- читать accessibility tree;
- извлекать текстовые элементы;
- искать usage / credits / reset / subscription patterns.

### 14.2 Fallback
Во второй очереди можно предусмотреть:
- ScreenCapture + OCR fallback
- только по явному включению пользователем

---

## 15. Архитектура приложения

### 15.1 AppShell
- запуск приложения
- menu bar entry
- settings window

### 15.2 ProcessWatcher
- отслеживание запуска Codex app
- отслеживание активного окна

### 15.3 AccessibilityReader
- чтение accessibility-дерева
- сбор всех доступных строк из окна

### 15.4 UsageParser
- извлечение e-mail
- извлечение процентов usage
- извлечение reset time
- извлечение subscription info
- confidence scoring

### 15.5 Storage
- локальное хранение аккаунтов
- локальное хранение snapshot-данных

### 15.6 NotificationManager
- планирование и отправка локальных уведомлений

---

## 16. Data model

```swift
struct Provider: Identifiable, Codable {
    let id: UUID
    var name: String
}
```

```swift
enum UsageStatus: String, Codable {
    case available
    case coolingDown
    case exhausted
    case unknown
    case stale
}
```

```swift
enum SubscriptionStatus: String, Codable {
    case active
    case expiringSoon
    case expired
    case unknown
}
```

```swift
struct Account: Identifiable, Codable {
    let id: UUID
    var provider: String
    var email: String?
    var label: String?
    var note: String?
    var priority: Int?
}
```

```swift
struct UsageSnapshot: Identifiable, Codable {
    let id: UUID
    var accountId: UUID
    var dailyPercentUsed: Double?
    var weeklyPercentUsed: Double?
    var dailyRemainingPercent: Double?
    var weeklyRemainingPercent: Double?
    var nextResetAt: Date?
    var subscriptionExpiresAt: Date?
    var usageStatus: UsageStatus
    var subscriptionStatus: SubscriptionStatus
    var sourceConfidence: Double
    var lastSyncedAt: Date?
    var rawExtractedStrings: [String]
}
```

---

## 17. UI-компоненты V1

### 17.1 Menu bar compact state
Показывает:
- иконку;
- краткий статус:
  - `D24 W71`
  - или `1h 13m`
  - или `--`

### 17.2 Dropdown panel
Показывает:
- активный аккаунт;
- список аккаунтов;
- provider;
- usage;
- reset;
- last sync;
- actions

### 17.3 Settings
Настройки:
- Launch at login
- Polling interval
- Notifications on/off
- Accessibility status
- Screen fallback on/off
- Reset all local data

---

## 18. Алгоритм синка

### 18.1 Polling
По умолчанию:
- раз в 10–15 секунд при активном Codex app
- раз в 60 секунд, если Codex app закрыт

### 18.2 Flow
1. Проверить, запущен ли Codex
2. Найти его активное окно
3. Считать accessibility-элементы
4. Извлечь строки
5. Прогнать parser
6. Обновить local store
7. Обновить UI
8. Проверить нужные уведомления

---

## 19. Parser rules

### 19.1 Email extraction
Использовать regex стандартного формата e-mail.

### 19.2 Usage extraction
Искать:
- `%`
- `daily`
- `weekly`
- `usage`
- `credits`
- `remaining`

### 19.3 Reset extraction
Искать паттерны:
- `resets in ...`
- `available in ...`
- `resets at ...`
- `available at ...`

### 19.4 Subscription extraction
Искать паттерны:
- `expires on ...`
- `renews on ...`
- `subscription ends ...`

### 19.5 Confidence scoring
Чем больше найдено релевантных признаков, тем выше confidence.

---

## 20. Edge cases
- Codex запущен, но usage screen не открыт
- e-mail не найден, но usage найден
- usage найден частично
- reset найден без даты
- подписка найдена без плана
- интерфейс Codex обновился и parser стал находить меньше данных

---

## 21. Acceptance criteria для MVP
MVP считается готовым, если:
1. Приложение работает как menu bar utility.
2. Видит, запущен ли Codex.
3. Может считать текст из окна Codex через Accessibility.
4. Может сохранить несколько аккаунтов.
5. Может показать статус хотя бы части аккаунтов.
6. Может показывать countdown, если найден reset.
7. Может отправить уведомление по завершении cooldown.
8. Не хранит чувствительные данные.

---

## 22. Roadmap

### V1
- Codex only
- multi-account
- usage tracking
- cooldown tracking
- menu bar UI
- notifications

### V2
- subscription expiry
- account priorities
- notes
- better UX

### V3
- Claude support
- multi-provider dashboard
- smart suggestions
- workflow layer

---

## 23. Позиционирование продукта
**LimitBar** — это menu bar приложение для отслеживания лимитов, cooldown и подписок по нескольким AI-аккаунтам, которое помогает без хаоса переключаться между Codex, Claude и другими AI coding tools.

---

## 24. Ключевая ценность
Приложение должно экономить внимание пользователя и убирать хаос при работе с несколькими AI-аккаунтами.

Пользователь должен в один взгляд понимать:
- где можно работать прямо сейчас;
- где скоро освободится лимит;
- где нужно продлить подписку;
- какой аккаунт лучше использовать следующим.
