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
            en: "LimitBar reads usage data from Codex and Claude accounts. Connect Claude below to enable real-time quota tracking.",
            ru: "LimitBar читает данные об использовании из аккаунтов Codex и Claude. Подключите Claude ниже для отслеживания квоты в реальном времени."
        )
    }
    var status: String { tr(en: "Status", ru: "Статус") }
    var save: String { tr(en: "Save", ru: "Сохранить") }
    var clear: String { tr(en: "Clear", ru: "Очистить") }
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
    var claudeWebSectionTitle: String { tr(en: "Claude Web Session", ru: "Claude Web Session") }
    var claudeCookieSectionTitle: String { tr(en: "Session Cookie", ru: "Cookie сессии") }
    var cookieLabel: String { tr(en: "Cookie", ru: "Cookie") }
    var sameDayFooterNote: String {
        tr(
            en: "\"Same day\" reminder fires at the start of the expiry day.",
            ru: "Напоминание «В тот же день» срабатывает в начале дня истечения."
        )
    }
    var pollingDefault: String { tr(en: "default", ru: "по умолч.") }
    var pollingFooter: String {
        tr(
            en: "More frequent polling gives faster updates but uses slightly more battery.",
            ru: "Более частый опрос даёт более быстрые обновления, но немного увеличивает расход батареи."
        )
    }
    var resetToDefaults: String { tr(en: "Reset to defaults", ru: "Сбросить к дефолтам") }
    var claudeCookieSecurityNote: String {
        tr(
            en: "The cookie is stored encrypted in your macOS Keychain and never sent anywhere except claude.ai.",
            ru: "Cookie хранится в зашифрованном виде в macOS Keychain и никуда не передаётся, кроме claude.ai."
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
    var cooldownFooter: String {
        tr(
            en: "LimitBar will notify you when a tracked account's usage quota resets and becomes available again.",
            ru: "LimitBar уведомит вас, когда квота использования отслеживаемого аккаунта сбросится и станет доступной снова."
        )
    }
    var noSubscriptionsNote: String {
        tr(
            en: "Reminders will activate automatically once LimitBar detects subscription expiry data for your accounts.",
            ru: "Напоминания активируются автоматически, как только LimitBar обнаружит дату истечения подписки для ваших аккаунтов."
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
    var priorityFooter: String {
        tr(
            en: "Priority controls display order. Primary accounts appear first in the menu bar.",
            ru: "Приоритет определяет порядок отображения. Основные аккаунты показываются первыми в меню-баре."
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
    var weeklyResetTitle: String { tr(en: "Weekly reset", ru: "Сброс недели") }
    var ready: String { tr(en: "Ready", ru: "Готово") }
    var offline: String { tr(en: "Offline", ru: "Офлайн") }
    var emptyAccountsTitle: String { tr(en: "No tracked accounts yet", ru: "Пока нет отслеживаемых аккаунтов") }
    var emptyAccountsConnectHint: String {
        tr(
            en: "Open Codex or connect Claude Web in Settings -> General to start tracking usage.",
            ru: "Откройте Codex или подключите Claude Web в Settings -> General, чтобы начать отслеживание usage."
        )
    }
    var emptyAccountsReadingHint: String {
        tr(
            en: "LimitBar is waiting for the first successful usage refresh.",
            ru: "LimitBar ждёт первое успешное обновление usage-данных."
        )
    }
    var settings: String { tr(en: "Settings…", ru: "Настройки…") }
    var updateAvailableTitle: String { tr(en: "Update available", ru: "Доступно обновление") }
    var downloadUpdate: String { tr(en: "Download update", ru: "Скачать обновление") }
    var dismissUpdate: String { tr(en: "Dismiss this update", ru: "Скрыть это обновление") }
    var quit: String { tr(en: "Quit", ru: "Выход") }
    var deleteAccountHelp: String { tr(en: "Delete account", ru: "Удалить аккаунт") }
    var switchAccountHelp: String { tr(en: "Switch to this account", ru: "Переключиться на этот аккаунт") }
    var activeAccountLabel: String { tr(en: "Active", ru: "Активен") }
    var tokensToday: String { tr(en: "Today", ru: "Сегодня") }
    var tokensWeek: String { tr(en: "Week", ru: "Неделя") }

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

    var shortHourUnit: String {
        tr(en: "h", ru: "ч")
    }

    var shortMinuteUnit: String {
        tr(en: "m", ru: "м")
    }

    var lessThanOneMinute: String {
        tr(en: "<1m", ru: "<1м")
    }

    func updateAvailableVersion(_ version: String) -> String {
        switch language {
        case .english:
            return "Version \(version) is ready to install."
        case .russian:
            return "Версия \(version) готова к установке."
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

    func synced(_ relative: String) -> String {
        tr(en: "Synced \(relative)", ru: "Синхронизировано \(relative)")
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

    func weeklyResetSummary(time: String, countdown: String) -> String {
        tr(
            en: "Weekly reset at \(time) (in \(countdown))",
            ru: "Сброс недели в \(time) (через \(countdown))"
        )
    }

    func weeklyResetReadySummary(time: String) -> String {
        tr(
            en: "Weekly reset at \(time) (ready)",
            ru: "Сброс недели в \(time) (готово)"
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
