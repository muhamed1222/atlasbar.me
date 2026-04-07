import SwiftUI
import WebKit

struct GeneralSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @State private var claudeCookieInput = ""
    @State private var isShowingClaudeWebSheet = false

    var body: some View {
        let strings = appModel.strings

        Form {
            Section(strings.trackingSourcesTitle) {
                Text(strings.trackingSourcesDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let persistenceErrorMessage = appModel.persistenceErrorMessage, !persistenceErrorMessage.isEmpty {
                Section(strings.localStorageErrorTitle) {
                    Text(persistenceErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let switchErrorMessage = appModel.switchErrorMessage, !switchErrorMessage.isEmpty {
                Section(strings.accountSwitchErrorTitle) {
                    Text(switchErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                Stepper(value: runningIntervalBinding, in: 5...60, step: 5) {
                    settingRow(
                        title: strings.whileCodexRunning,
                        value: strings.seconds(Int(runningIntervalBinding.wrappedValue)),
                        isDefault: appModel.settings.pollingWhenRunning == nil
                    )
                }
                Stepper(value: closedIntervalBinding, in: 30...300, step: 15) {
                    settingRow(
                        title: strings.whileCodexClosed,
                        value: strings.seconds(Int(closedIntervalBinding.wrappedValue)),
                        isDefault: appModel.settings.pollingWhenClosed == nil
                    )
                }
                if appModel.settings.pollingWhenRunning != nil || appModel.settings.pollingWhenClosed != nil {
                    Button(strings.resetToDefaults) {
                        appModel.resetPollingToDefaults()
                    }
                    .font(.footnote)
                }
            } header: {
                Text(strings.polling)
            } footer: {
                Text(strings.pollingFooter)
            }

            Section(strings.claudeWebSectionTitle) {
                settingRow(
                    title: strings.status,
                    value: appModel.claudeWebSessionConnected
                        ? strings.claudeWebConnected
                        : strings.claudeWebMissing
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.claudeWebDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 10) {
                        Button(strings.claudeWebConnect) {
                            appModel.prepareClaudeWebLogin()
                            isShowingClaudeWebSheet = true
                        }
                        .disabled(!appModel.claudeWebSessionAvailable)

                        Button(strings.clear) {
                            appModel.clearClaudeWebSession()
                        }
                        .disabled(!appModel.claudeWebSessionConnected)
                    }

                    if let message = appModel.claudeWebSessionErrorMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(strings.claudeCookieSectionTitle) {
                settingRow(
                    title: strings.cookieLabel,
                    value: appModel.claudeCookieConfigured
                        ? strings.claudeCookieConnected
                        : strings.claudeCookieMissing
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.claudeCookieFieldTitle)
                        .font(.headline)

                    Text(strings.claudeCookieDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(strings.claudeCookieSecurityNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    TextField(
                        strings.claudeCookiePlaceholder,
                        text: $claudeCookieInput,
                        axis: .vertical
                    )
                    .lineLimit(4...8)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                    HStack(spacing: 10) {
                        Button(strings.save) {
                            if appModel.saveClaudeSessionCookie(claudeCookieInput) {
                                claudeCookieInput = ""
                            }
                        }
                        .disabled(claudeCookieInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button(strings.clear) {
                            appModel.clearClaudeSessionCookie()
                        }
                        .disabled(!appModel.claudeCookieConfigured)
                    }

                    if let message = appModel.claudeCookieErrorMessage, !message.isEmpty {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }

            Section(strings.languageTitle) {
                Picker(
                    strings.appLanguage,
                    selection: Binding(
                        get: { appModel.settings.language },
                        set: { appModel.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayLabel(language: appModel.resolvedLanguage)).tag(language)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(strings.general)
        .sheet(isPresented: $isShowingClaudeWebSheet) {
            ClaudeWebSessionSheet(
                strings: strings,
                webView: appModel.claudeWebLoginWebView,
                onDone: {
                    appModel.finalizeClaudeWebLogin()
                    isShowingClaudeWebSheet = false
                }
            )
        }
    }

    private var runningIntervalBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.pollingWhenRunning ?? 15 },
            set: { appModel.updatePollingInterval($0, codexRunning: true) }
        )
    }

    private var closedIntervalBinding: Binding<Double> {
        Binding(
            get: { appModel.settings.pollingWhenClosed ?? 60 },
            set: { appModel.updatePollingInterval($0, codexRunning: false) }
        )
    }

    private func settingRow(title: String, value: String, isDefault: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(isDefault ? "\(value) (\(appModel.strings.pollingDefault))" : value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

private struct ClaudeWebSessionSheet: View {
    let strings: AppStrings
    let webView: WKWebView?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(strings.claudeWebSheetTitle)
                    .font(.headline)
                Spacer()
                Button(strings.done, action: onDone)
            }
            .padding(16)

            Divider()

            Group {
                if let webView {
                    ClaudeWebViewContainer(webView: webView)
                } else {
                    Text(strings.noData)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 840, minHeight: 620)
        }
    }
}

private struct ClaudeWebViewContainer: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> WKWebView {
        webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
