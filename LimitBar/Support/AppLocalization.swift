import Foundation

enum ResolvedAppLanguage: String, Equatable {
    case english = "en"
    case russian = "ru"

    var locale: Locale {
        Locale(identifier: rawValue)
    }
}

enum AppLanguage: String, Codable, CaseIterable, Equatable, Identifiable {
    case system
    case english
    case russian

    var id: String { rawValue }

    func resolved(systemLanguageCode: String = Locale.preferredLanguages.first ?? "en") -> ResolvedAppLanguage {
        switch self {
        case .system:
            let normalized = systemLanguageCode.lowercased()
            return normalized.hasPrefix("ru") ? .russian : .english
        case .english:
            return .english
        case .russian:
            return .russian
        }
    }

    func displayLabel(language: ResolvedAppLanguage) -> String {
        switch (language, self) {
        case (.english, .system):
            return "System"
        case (.english, .english):
            return "English"
        case (.english, .russian):
            return "Russian"
        case (.russian, .system):
            return "Системный"
        case (.russian, .english):
            return "English"
        case (.russian, .russian):
            return "Русский"
        }
    }
}

struct AppStrings {
    let language: ResolvedAppLanguage

    var general: String { tr(en: "General", ru: "Основные") }
    var notifications: String { tr(en: "Notifications", ru: "Уведомления") }
    var accounts: String { tr(en: "Accounts", ru: "Аккаунты") }
    var polling: String { tr(en: "Polling", ru: "Опрос") }
    var languageTitle: String { tr(en: "Language", ru: "Язык") }
    var appLanguage: String { tr(en: "App language", ru: "Язык приложения") }
    var localStorageErrorTitle: String { tr(en: "Storage issue", ru: "Проблема с хранилищем") }
    var accountSwitchErrorTitle: String { tr(en: "Account switching", ru: "Переключение аккаунта") }
    var trackingSourcesTitle: String { tr(en: "Tracking sources", ru: "Источники данных") }
    var trackingSourcesDescription: String {
        tr(
            en: "LimitBar reads Codex usage from ~/.codex/auth.json and the usage API. Claude usage comes from a connected Claude web session when available, or falls back to a saved Claude cookie and local token logs.",
            ru: "LimitBar читает usage Codex через ~/.codex/auth.json и usage API. Данные Claude берутся из подключённой web-сессии Claude, а при необходимости откатываются к сохранённому cookie и локальным token-логам."
        )
    }
    var status: String { tr(en: "Status", ru: "Статус") }
    var save: String { tr(en: "Save", ru: "Сохранить") }
    var clear: String { tr(en: "Clear", ru: "Очистить") }
    var claudeQuotaTitle: String { tr(en: "Claude quota", ru: "Квота Claude") }
    var claudeWebConnected: String { tr(en: "Web session connected", ru: "Web-сессия подключена") }
    var claudeWebMissing: String { tr(en: "Web session missing", ru: "Web-сессия не подключена") }
    var claudeWebDescription: String {
        tr(
            en: "Recommended: sign in to claude.ai inside LimitBar once. Then Claude percentages are fetched from the same web session instead of guessed from local token logs.",
            ru: "Рекомендуется: один раз войти в claude.ai прямо внутри LimitBar. После этого проценты Claude будут браться из той же web-сессии, а не вычисляться по локальным token-логам."
        )
    }
    var claudeWebConnect: String { tr(en: "Connect Claude Web", ru: "Подключить Claude Web") }
    var claudeWebSheetTitle: String { tr(en: "Claude Web Session", ru: "Claude Web Session") }
    var done: String { tr(en: "Done", ru: "Готово") }
    var claudeCookieConnected: String { tr(en: "Cookie connected", ru: "Cookie подключён") }
    var claudeCookieMissing: String { tr(en: "Cookie missing", ru: "Cookie отсутствует") }
    var claudeCookieFieldTitle: String { tr(en: "Claude session cookie", ru: "Cookie сессии Claude") }
    var claudeCookieDescription: String {
        tr(
            en: "Paste the Cookie header from claude.ai/settings/usage to unlock real session and weekly percentages for Claude accounts.",
            ru: "Вставьте заголовок Cookie со страницы claude.ai/settings/usage, чтобы получать реальные проценты по сессии и неделе для аккаунтов Claude."
        )
    }
    var claudeCookiePlaceholder: String {
        tr(
            en: "Cookie: sessionKey=...; lastActiveOrg=...;",
            ru: "Cookie: sessionKey=...; lastActiveOrg=...;"
        )
    }
    var whileCodexRunning: String { tr(en: "While Codex is running", ru: "Когда Codex запущен") }
    var whileCodexClosed: String { tr(en: "While Codex is closed", ru: "Когда Codex закрыт") }
    var cooldown: String { tr(en: "Cooldown", ru: "Ожидание") }
    var cooldownReadyNotifications: String { tr(en: "Cooldown ready notifications", ru: "Уведомления о завершении ожидания") }
    var renewalReminders: String { tr(en: "Renewal reminders", ru: "Напоминания о продлении") }
    var renewalRemindersFooter: String {
        tr(
            en: "Renewal reminders are scheduled automatically from the latest subscription expiry and update when these toggles change.",
            ru: "Напоминания о продлении создаются автоматически по последней дате окончания подписки и обновляются при изменении этих переключателей."
        )
    }
    var sameDay: String { tr(en: "Same day", ru: "В тот же день") }
    var oneDay: String { tr(en: "1 day", ru: "1 дн.") }
    var priority: String { tr(en: "Priority", ru: "Приоритет") }
    var plan: String { tr(en: "Plan", ru: "Тариф") }
    var note: String { tr(en: "Note", ru: "Заметка") }
    var identity: String { tr(en: "Identity", ru: "Данные") }
    var account: String { tr(en: "Account", ru: "Аккаунт") }
    var provider: String { tr(en: "Provider", ru: "Провайдер") }
    var subscription: String { tr(en: "Subscription", ru: "Подписка") }
    var dailyReset: String { tr(en: "Daily", ru: "Ежедневная") }
    var weeklyReset: String { tr(en: "Weekly", ru: "Еженедельная") }
    var reset: String { tr(en: "Reset", ru: "Сброс") }
    var time: String { tr(en: "Time", ru: "Время") }
    var lastSync: String { tr(en: "Last sync", ru: "Последняя синхронизация") }
    var nextReset: String { tr(en: "Next reset", ru: "Следующий сброс") }
    var selectAccount: String { tr(en: "Select an account", ru: "Выберите аккаунт") }
    var selectAccountDescription: String {
        tr(
            en: "Choose an account from the list to edit priority and note.",
            ru: "Выберите аккаунт в списке, чтобы изменить приоритет и заметку."
        )
    }
    var optionalNoteFooter: String {
        tr(
            en: "Optional note for renewal context, handoff, or reminders",
            ru: "Необязательная заметка для продления, передачи контекста или напоминаний"
        )
    }
    var savedLocalNoteFooter: String { tr(en: "Saved locally for this account", ru: "Сохранено локально для этого аккаунта") }
    var noData: String { tr(en: "No data", ru: "Нет данных") }
    var unknownStatus: String { tr(en: "Unknown status", ru: "Статус неизвестен") }
    var expired: String { tr(en: "Expired", ru: "Истекла") }
    var expiresToday: String { tr(en: "Expires today", ru: "Истекает сегодня") }
    var sessionReset: String { tr(en: "Session reset", ru: "Сброс сессии") }
    var updatedPrefix: String { tr(en: "Updated", ru: "Обновлено") }
    var syncedPrefix: String { tr(en: "Synced", ru: "Синхронизировано") }
    var staleSyncedSeparator: String { tr(en: "Stale ·", ru: "Устарело ·") }
    var ready: String { tr(en: "Ready", ru: "Готово") }
    var offline: String { tr(en: "Offline", ru: "Офлайн") }
    var openCodexToStartTracking: String { tr(en: "Open Codex or connect Claude to start tracking", ru: "Откройте Codex или подключите Claude, чтобы начать отслеживание") }
    var readingUsageData: String { tr(en: "Reading Codex and Claude usage…", ru: "Читаю usage-данные Codex и Claude…") }
    var refreshNow: String { tr(en: "Refresh now", ru: "Обновить сейчас") }
    var openCodex: String { tr(en: "Open Codex", ru: "Открыть Codex") }
    var settings: String { tr(en: "Settings…", ru: "Настройки…") }
    var quit: String { tr(en: "Quit", ru: "Выход") }
    var codexRunning: String { tr(en: "Codex running", ru: "Codex запущен") }
    var codexNotRunning: String { tr(en: "Codex not running", ru: "Codex не запущен") }
    var deleteAccountHelp: String { tr(en: "Delete account", ru: "Удалить аккаунт") }
    var switchAccountHelp: String { tr(en: "Switch to this account", ru: "Переключиться на этот аккаунт") }
    var activeAccountLabel: String { tr(en: "Active", ru: "Активен") }
    var switchingAccount: String { tr(en: "Switching…", ru: "Переключение…") }
    var tokensToday: String { tr(en: "Today", ru: "Сегодня") }
    var tokensWeek: String { tr(en: "Week", ru: "Неделя") }
    var tokensUnit: String { tr(en: "tokens", ru: "токенов") }

    func formattedTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        }
        if count >= 1_000 {
            return String(format: "%.0fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
    var emailLabel: String { tr(en: "Email", ru: "Email") }
    var emailPlaceholder: String { tr(en: "your@email.com", ru: "your@email.com") }
    var deleteAccountTitle: String { tr(en: "Delete this account from LimitBar?", ru: "Удалить этот аккаунт из LimitBar?") }
    var delete: String { tr(en: "Delete", ru: "Удалить") }
    var cancel: String { tr(en: "Cancel", ru: "Отмена") }
    var session: String { tr(en: "Session", ru: "Сессия") }
    var weekly: String { tr(en: "Weekly", ru: "Неделя") }

    func seconds(_ value: Int) -> String {
        switch language {
        case .english:
            return "\(value) seconds"
        case .russian:
            return "\(value) сек."
        }
    }

    func days(_ value: Int) -> String {
        switch language {
        case .english:
            return "\(value) days"
        case .russian:
            return "\(value) дн."
        }
    }

    func charactersCount(_ count: Int) -> String {
        switch language {
        case .english:
            return "\(count) characters"
        case .russian:
            return "\(count) символов"
        }
    }

    func localStorageError(_ details: String) -> String {
        tr(
            en: "LimitBar found a local storage issue: \(details)",
            ru: "LimitBar обнаружил проблему с локальным хранилищем: \(details)"
        )
    }

    func statusLabel(_ status: UsageStatus) -> String {
        switch (language, status) {
        case (.english, .available):
            return "Available"
        case (.english, .coolingDown):
            return "Cooling down"
        case (.english, .exhausted):
            return "Exhausted"
        case (.english, .unknown):
            return "Unknown"
        case (.english, .stale):
            return "Stale"
        case (.russian, .available):
            return "Доступен"
        case (.russian, .coolingDown):
            return "Ожидание"
        case (.russian, .exhausted):
            return "Исчерпан"
        case (.russian, .unknown):
            return "Неизвестно"
        case (.russian, .stale):
            return "Устарел"
        }
    }

    func dataQualityLabel(_ quality: DataQualityState) -> String {
        switch (language, quality) {
        case (.english, .live):
            return "Live"
        case (.english, .cached):
            return "Cached"
        case (.english, .stale):
            return "Stale"
        case (.english, .localOnly):
            return "Local only"
        case (.russian, .live):
            return "Актуально"
        case (.russian, .cached):
            return "Кэш"
        case (.russian, .stale):
            return "Устарело"
        case (.russian, .localOnly):
            return "Локально"
        }
    }

    func priorityLabel(_ priority: AccountPriority) -> String {
        switch (language, priority) {
        case (.english, .none):
            return "None"
        case (.english, .primary):
            return "Primary"
        case (.english, .backup):
            return "Backup"
        case (.english, .auxiliary):
            return "Auxiliary"
        case (.russian, .none):
            return "Нет"
        case (.russian, .primary):
            return "Основной"
        case (.russian, .backup):
            return "Резервный"
        case (.russian, .auxiliary):
            return "Дополнительный"
        }
    }

    func subscriptionStateLabel(_ state: SubscriptionDerivedState) -> String {
        switch (language, state) {
        case (.english, .active):
            return "Active"
        case (.english, .expiringSoon):
            return "Expires soon"
        case (.english, .expired):
            return "Expired"
        case (.english, .unknown):
            return "Unknown"
        case (.russian, .active):
            return "Активна"
        case (.russian, .expiringSoon):
            return "Скоро истекает"
        case (.russian, .expired):
            return "Истекла"
        case (.russian, .unknown):
            return "Неизвестно"
        }
    }

    func synced(_ relative: String) -> String {
        tr(en: "Synced \(relative)", ru: "Синхронизировано \(relative)")
    }

    func updated(_ relative: String) -> String {
        tr(en: "Updated \(relative)", ru: "Обновлено \(relative)")
    }

    func staleSynced(_ relative: String) -> String {
        tr(en: "Stale · Synced \(relative)", ru: "Устарело · Синхронизировано \(relative)")
    }

    func expires(_ date: String) -> String {
        tr(en: "Expires \(date)", ru: "Истекает \(date)")
    }

    func resetsIn(_ countdown: String) -> String {
        tr(en: "Resets in \(countdown)", ru: "Сброс через \(countdown)")
    }

    func sessionResetSummary(time: String, countdown: String) -> String {
        tr(
            en: "Session reset at \(time) (in \(countdown))",
            ru: "Сброс сессии в \(time) (через \(countdown))"
        )
    }

    func sessionResetReadySummary(time: String) -> String {
        tr(
            en: "Session reset at \(time) (ready)",
            ru: "Сброс сессии в \(time) (готово)"
        )
    }

    private func tr(en: String, ru: String) -> String {
        switch language {
        case .english:
            return en
        case .russian:
            return ru
        }
    }
}

func localizedRelativeDate(_ date: Date, language: ResolvedAppLanguage, now: Date = .now) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.locale = language.locale
    formatter.unitsStyle = .full
    formatter.dateTimeStyle = .named
    return formatter.localizedString(for: date, relativeTo: now)
}

func localizedMonthDay(_ date: Date, language: ResolvedAppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.setLocalizedDateFormatFromTemplate("MMM d")
    return formatter.string(from: date)
}

func localizedTimeOfDay(_ date: Date, language: ResolvedAppLanguage) -> String {
    let formatter = DateFormatter()
    formatter.locale = language.locale
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: date)
}
