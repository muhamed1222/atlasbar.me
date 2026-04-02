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
    var openCodexToStartTracking: String { tr(en: "Open Codex to start tracking", ru: "Откройте Codex, чтобы начать отслеживание") }
    var readingUsageData: String { tr(en: "Reading usage data…", ru: "Читаю usage-данные…") }
    var refreshNow: String { tr(en: "Refresh now", ru: "Обновить сейчас") }
    var openCodex: String { tr(en: "Open Codex", ru: "Открыть Codex") }
    var settings: String { tr(en: "Settings…", ru: "Настройки…") }
    var quit: String { tr(en: "Quit", ru: "Выход") }
    var codexRunning: String { tr(en: "Codex running", ru: "Codex запущен") }
    var codexNotRunning: String { tr(en: "Codex not running", ru: "Codex не запущен") }
    var deleteAccountHelp: String { tr(en: "Delete account", ru: "Удалить аккаунт") }
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
