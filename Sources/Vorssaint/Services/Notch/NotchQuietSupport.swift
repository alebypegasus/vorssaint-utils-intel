// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Quiet hours gate for passive Dynamic Island notices. Explicit hardware
/// feedback (volume, brightness, keyboard light, mic mute, input source,
/// timers, battery alerts, captures, accessories) still shows as expected.
enum NotchQuiet {
    static let defaultStartHour = 22
    static let defaultEndHour = 8

    static func normalizedHour(_ hour: Int) -> Int {
        ((hour % 24) + 24) % 24
    }

    static func isActive(hour: Int, start: Int, end: Int) -> Bool {
        let h = normalizedHour(hour)
        let s = normalizedHour(start)
        let e = normalizedHour(end)
        if s == e { return false }
        return s < e ? (h >= s && h < e) : (h >= s || h < e)
    }

    static func isActive(in defaults: UserDefaults = .standard, now: Date = Date(),
                         calendar: Calendar = .current) -> Bool {
        guard defaults.bool(forKey: DefaultsKey.notchQuietHours) else { return false }
        let start = defaults.object(forKey: DefaultsKey.notchQuietStart) as? Int ?? defaultStartHour
        let end = defaults.object(forKey: DefaultsKey.notchQuietEnd) as? Int ?? defaultEndHour
        return isActive(hour: calendar.component(.hour, from: now), start: start, end: end)
    }

    /// Passive notices pause during quiet hours; user-triggered hardware HUDs stay responsive.
    static func suppresses(_ event: NotchEvent, in defaults: UserDefaults = .standard,
                           now: Date = Date(), calendar: Calendar = .current) -> Bool {
        switch event {
        case .systemNotification, .track, .download, .clipboard, .agents:
            return isActive(in: defaults, now: now, calendar: calendar)
        case .volume, .brightness, .keyboardLight, .microphone, .inputSource,
             .battery, .capture, .timer, .accessory, .watch:
            return false
        }
    }
}

/// Localized copy for community Dynamic Island and General settings additions.
struct NotchExtrasStrings {
    let privacyDotsTitle: String
    let privacyDotsCaption: String
    let quietHoursTitle: String
    let quietHoursCaption: String
    let quietFrom: String
    let quietTo: String
    let claudeLiveTitle: String
    let claudeLiveCaption: String
    let claudeLiveAnswerInNotch: String
    let claudeLiveListening: String
    let claudeLiveConnect: String
    let claudeLiveDisconnect: String
    let claudeLiveConnected: String
    let suppressSupportPopupTitle: String
    let suppressSupportPopupCaption: String

    static func localized(_ language: AppLanguage) -> NotchExtrasStrings {
        switch language {
        case .ptBR:
            return NotchExtrasStrings(
                privacyDotsTitle: "Indicadores de câmera e microfone",
                privacyDotsCaption: "Mostra pontos verde (câmera) e laranja (microfone) na Ilha Dinâmica quando um app estiver usando o hardware.",
                quietHoursTitle: "Horário silencioso",
                quietHoursCaption: "Pausa avisos passivos da Ilha Dinâmica (notificações, faixas, downloads e agentes) no intervalo escolhido.",
                quietFrom: "De",
                quietTo: "Até",
                claudeLiveTitle: "Hooks ao vivo do Claude Code",
                claudeLiveCaption: "Escuta eventos locais em 127.0.0.1:47615 para mostrar sessões, planos e aprovações na Ilha Dinâmica.",
                claudeLiveAnswerInNotch: "Responder permissões e perguntas na Ilha Dinâmica",
                claudeLiveListening: "Escutando em 127.0.0.1:47615",
                claudeLiveConnect: "Conectar hooks",
                claudeLiveDisconnect: "Desconectar",
                claudeLiveConnected: "Hooks conectados",
                suppressSupportPopupTitle: "Ocultar pop-up de apoio após atualizações",
                suppressSupportPopupCaption: "Evita exibir automaticamente a tela de apoio ao projeto depois de instalar novas versões."
            )
        default:
            return NotchExtrasStrings(
                privacyDotsTitle: "Camera & microphone indicators",
                privacyDotsCaption: "Show green (camera) and orange (microphone) dots in the Dynamic Island whenever an app uses them.",
                quietHoursTitle: "Quiet hours",
                quietHoursCaption: "Pause passive Dynamic Island notices (notifications, tracks, downloads and agents) during the chosen hours.",
                quietFrom: "From",
                quietTo: "To",
                claudeLiveTitle: "Claude Code live hooks",
                claudeLiveCaption: "Listen locally on 127.0.0.1:47615 to show live sessions, plan reviews and tool approvals in the Dynamic Island.",
                claudeLiveAnswerInNotch: "Answer permission prompts and questions in the Dynamic Island",
                claudeLiveListening: "Listening on 127.0.0.1:47615",
                claudeLiveConnect: "Connect hooks",
                claudeLiveDisconnect: "Disconnect",
                claudeLiveConnected: "Hooks connected",
                suppressSupportPopupTitle: "Hide post-update support popup",
                suppressSupportPopupCaption: "Skip showing the automatic support invitation after installing future updates."
            )
        }
    }
}
