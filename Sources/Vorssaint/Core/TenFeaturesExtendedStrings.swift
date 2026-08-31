// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Multilingual localization strings for the 10 deep macOS features:
/// 1. Smart App Uninstaller
/// 2. Startup & Extension Manager
/// 3. Battery Health Guard
/// 4. Mini System HUD
/// 5. Privacy & Permission Auditor
/// 6. Desktop & Downloads Auto-Organizer
/// 7. Secure File Shredder
/// 8. Developer Environment Doctor
/// 9. Turbo Game & Focus Booster
/// 10. Smart Network & DNS Switcher
struct TenFeaturesExtendedStrings {
    // Tool Titles
    let titleUninstaller: String
    let titleStartupManager: String
    let titleBatteryGuard: String
    let titleMiniHUD: String
    let titlePrivacyAuditor: String
    let titleAutoOrganizer: String
    let titleFileShredder: String
    let titleDevDoctor: String
    let titleTurboBoost: String
    let titleNetworkOptimizer: String

    // Subtitles / Captions
    let captionUninstaller: String
    let captionStartupManager: String
    let captionBatteryGuard: String
    let captionMiniHUD: String
    let captionPrivacyAuditor: String
    let captionAutoOrganizer: String
    let captionFileShredder: String
    let captionDevDoctor: String
    let captionTurboBoost: String
    let captionNetworkOptimizer: String

    static func localized(_ language: AppLanguage) -> TenFeaturesExtendedStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .es: return .es
        case .fr: return .fr
        case .de: return .de
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .ru: return .ru
        case .tr: return .tr
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension TenFeaturesExtendedStrings {
    static let enUS = TenFeaturesExtendedStrings(
        titleUninstaller: "Smart App Uninstaller",
        titleStartupManager: "Startup & Extension Manager",
        titleBatteryGuard: "Battery Health Guard",
        titleMiniHUD: "Mini System HUD",
        titlePrivacyAuditor: "Privacy & Permissions",
        titleAutoOrganizer: "Auto-Organizer",
        titleFileShredder: "Secure File Shredder",
        titleDevDoctor: "Developer Doctor",
        titleTurboBoost: "Turbo Game & Focus Mode",
        titleNetworkOptimizer: "Network & DNS Optimizer",
        captionUninstaller: "Scan and eliminate deep leftover caches, preferences, and daemons of removed applications.",
        captionStartupManager: "Audit, disable, and clean Login Items, LaunchAgents, and background daemons.",
        captionBatteryGuard: "Detailed hardware diagnostics: cycle count, battery health (SoH), temperature, and charging limiter.",
        captionMiniHUD: "Floating real-time micro-monitor with sparkline charts for CPU, GPU, RAM, Network, and SoC temperature.",
        captionPrivacyAuditor: "Inspect TCC permissions (Camera, Microphone, Disk) and revoke access for orphaned apps.",
        captionAutoOrganizer: "Automatically organize cluttered Desktop and Downloads folders into categorized subfolders.",
        captionFileShredder: "Military-grade irreversible file erasure using DoD 5220.22-M and Gutmann multi-pass algorithms.",
        captionDevDoctor: "Specialized workstation cleaner: Docker prune, old node_modules, Xcode simulators, and package caches.",
        captionTurboBoost: "1-click system boost: suspends background sync daemons, purges RAM, and activates extreme focus for gaming.",
        captionNetworkOptimizer: "Live latency/jitter diagnostic tester and 1-click DNS profile switcher (Cloudflare, Google, Quad9, AdGuard)."
    )

    static let ptBR = TenFeaturesExtendedStrings(
        titleUninstaller: "Desinstalador Profundo",
        titleStartupManager: "Gerenciador de Inicialização",
        titleBatteryGuard: "Guardião da Bateria",
        titleMiniHUD: "Mini Monitor HUD",
        titlePrivacyAuditor: "Auditor de Privacidade",
        titleAutoOrganizer: "Organizador Automático",
        titleFileShredder: "Destruidor de Arquivos",
        titleDevDoctor: "Médico de Desenvolvimento",
        titleTurboBoost: "Modo Turbo & Foco Gamer",
        titleNetworkOptimizer: "Otimizador de Rede e DNS",
        captionUninstaller: "Rastreia e elimina pastas residuais em ~/Library, preferências, caches e daemons de apps desinstalados.",
        captionStartupManager: "Audite, desative e remova Login Items, LaunchAgents e LaunchDaemons que pesam no boot.",
        captionBatteryGuard: "Diagnóstico profundo via IOKit: ciclos reais, capacidade vs. fábrica (SoH), temperatura e limite de 80%.",
        captionMiniHUD: "Mini monitor flutuante com gráficos sparkline de CPU, GPU, RAM, Rede e temperatura do chip em tempo real.",
        captionPrivacyAuditor: "Audite permissões de Câmera, Microfone, Acessibilidade e Disco de apps antigos com 1 clique.",
        captionAutoOrganizer: "Organize arquivos soltos na Mesa e Downloads em pastas temáticas com botão de Desfazer (Undo).",
        captionFileShredder: "Destruição irreversível de arquivos confidenciais usando padrões militares DoD 5220.22-M e Gutmann.",
        captionDevDoctor: "Limpeza para desenvolvedores: Docker prune, node_modules antigos, simuladores Xcode e caches de pacotes.",
        captionTurboBoost: "Impulso de 1 clique: suspende sincronizadores pesados, libera RAM inativa e ativa foco total para jogos.",
        captionNetworkOptimizer: "Teste de latência/jitter e troca rápida de perfis DNS (Cloudflare 1.1.1.1, Google, Quad9, AdGuard)."
    )

    static let es = TenFeaturesExtendedStrings(
        titleUninstaller: "Desinstalador profundo",
        titleStartupManager: "Gestor de inicio y extensiones",
        titleBatteryGuard: "Salud de la batería",
        titleMiniHUD: "Mini monitor HUD",
        titlePrivacyAuditor: "Auditor de privacidad",
        titleAutoOrganizer: "Organizador automático",
        titleFileShredder: "Destructor seguro de archivos",
        titleDevDoctor: "Doctor de desarrollo",
        titleTurboBoost: "Modo Turbo & Juegos",
        titleNetworkOptimizer: "Optimizador de red y DNS",
        captionUninstaller: "Elimina residuos profundos, preferencias y daemons de aplicaciones desinstaladas.",
        captionStartupManager: "Supervisa y desactiva ítems de inicio, LaunchAgents y daemons en segundo plano.",
        captionBatteryGuard: "Diagnóstico de hardware: recuento de ciclos, salud de batería, temperatura y alertas.",
        captionMiniHUD: "Mini monitor flotante en tiempo real para CPU, GPU, RAM, red y temperatura.",
        captionPrivacyAuditor: "Audita permisos de cámara, micrófono, accesibilidad y revoca accesos obsoletos.",
        captionAutoOrganizer: "Organiza automáticamente el Escritorio y Descargas en carpetas por categoría.",
        captionFileShredder: "Borrado permanente e irrecuperable de archivos según normas militares DoD y Gutmann.",
        captionDevDoctor: "Limpieza para desarrolladores: Docker prune, node_modules antiguos, simuladores y cachés.",
        captionTurboBoost: "Optimización con 1 clic: libera RAM, suspende sincronizaciones y enfoca el Mac en juegos.",
        captionNetworkOptimizer: "Diagnóstico de latencia y cambio rápido de perfiles DNS seguros (Cloudflare, Google, Quad9)."
    )

    static let fr = TenFeaturesExtendedStrings(
        titleUninstaller: "Désinstallateur avancé",
        titleStartupManager: "Gestionnaire de démarrage",
        titleBatteryGuard: "Santé de la batterie",
        titleMiniHUD: "Mini HUD système",
        titlePrivacyAuditor: "Auditeur de confidentialité",
        titleAutoOrganizer: "Organisateur automatique",
        titleFileShredder: "Destructeur de fichiers",
        titleDevDoctor: "Docteur développeur",
        titleTurboBoost: "Mode Turbo & Jeux",
        titleNetworkOptimizer: "Optimiseur réseau & DNS",
        captionUninstaller: "Supprime les résidus profonds, préférences et daemons d’applications désinstallées.",
        captionStartupManager: "Auditez et désactivez les éléments d’ouverture, LaunchAgents et daemons.",
        captionBatteryGuard: "Diagnostics matériels : cycles réels, état de santé, température et limiteur de charge.",
        captionMiniHUD: "Moniteur flottant en temps réel avec graphiques pour CPU, GPU, RAM, réseau et température.",
        captionPrivacyAuditor: "Inspectez les autorisations système (Caméra, Micro, Disque) et révoquez les accès inutiles.",
        captionAutoOrganizer: "Organise automatiquement le Bureau et Téléchargements dans des dossiers thématiques.",
        captionFileShredder: "Destruction définitive et irréversible de fichiers selon les standards DoD et Gutmann.",
        captionDevDoctor: "Nettoyage développeur : Docker prune, node_modules inutilisés, simulateurs et caches.",
        captionTurboBoost: "Boost en 1 clic : libère la RAM, met en veille les synchronisations et optimise les jeux.",
        captionNetworkOptimizer: "Test de latence et changement instantané de DNS sécurisés (Cloudflare, Google, Quad9)."
    )

    static let de = TenFeaturesExtendedStrings(
        titleUninstaller: "Intelligenter Deinstallierer",
        titleStartupManager: "Autostart- & Daemon-Manager",
        titleBatteryGuard: "Batterie-Wächter",
        titleMiniHUD: "Mini-System-HUD",
        titlePrivacyAuditor: "Datenschutz-Auditor",
        titleAutoOrganizer: "Automatischer Datei-Organizer",
        titleFileShredder: "Sicherer Aktenvernichter",
        titleDevDoctor: "Entwickler-Doktor",
        titleTurboBoost: "Turbo- & Spiele-Modus",
        titleNetworkOptimizer: "Netzwerk- & DNS-Optimierer",
        captionUninstaller: "Findet und entfernt tiefsitzende Reste und Daemons gelöschter Apps.",
        captionStartupManager: "Überprüfen und deaktivieren Sie Anmeldeobjekte, LaunchAgents und Daemons.",
        captionBatteryGuard: "Hardware-Diagnose: Ladezyklen, Akkugesundheit, Temperatur und Ladelimit-Hinweise.",
        captionMiniHUD: "Schwebender Echtzeit-Monitor mit Verlaufsdiagrammen für CPU, GPU, RAM, Netzwerk und Temperatur.",
        captionPrivacyAuditor: "Prüfen Sie Berechtigungen für Kamera, Mikrofon und Festplatte und entziehen Sie verwaiste Zugriffe.",
        captionAutoOrganizer: "Räumt Schreibtisch und Downloads automatisch in übersichtliche Unterordner auf.",
        captionFileShredder: "Endgültige und unwiderrufliche Datenvernichtung nach DoD 5220.22-M und Gutmann.",
        captionDevDoctor: "Entwickler-Werkzeug: Docker-Bereinigung, alte node_modules, Xcode-Simulatoren und Caches.",
        captionTurboBoost: "1-Klick-Beschleunigung: gibt RAM frei, pausiert Cloud-Synchronisierungen und maximiert Leistung.",
        captionNetworkOptimizer: "Latenztest und Schnellwechsel sicherer DNS-Profile (Cloudflare, Google, Quad9)."
    )

    static let it = TenFeaturesExtendedStrings(
        titleUninstaller: "Disinstallatore avanzato",
        titleStartupManager: "Gestore avvio ed estensioni",
        titleBatteryGuard: "Salute della batteria",
        titleMiniHUD: "Mini HUD di sistema",
        titlePrivacyAuditor: "Auditor di privacy",
        titleAutoOrganizer: "Organizzatore automatico",
        titleFileShredder: "Distruttore di file sicuro",
        titleDevDoctor: "Dottore per sviluppatori",
        titleTurboBoost: "Modalità Turbo & Giochi",
        titleNetworkOptimizer: "Ottimizzatore rete e DNS",
        captionUninstaller: "Elimina residui nascosti, preferenze e daemon delle app disinstallate.",
        captionStartupManager: "Verifica e disattiva elementi di login, LaunchAgent e daemon in background.",
        captionBatteryGuard: "Diagnostica hardware: cicli di carica, salute della batteria, temperatura e avvisi.",
        captionMiniHUD: "Monitor fluttuante in tempo reale per CPU, GPU, RAM, traffico di rete e temperatura.",
        captionPrivacyAuditor: "Controlla le autorizzazioni di fotocamera, microfono e disco e revoca gli accessi inutilizzati.",
        captionAutoOrganizer: "Organizza automaticamente Scrivania e Download in cartelle suddivise per categoria.",
        captionFileShredder: "Distruzione permanente dei file con algoritmi certificati DoD e Gutmann.",
        captionDevDoctor: "Pulizia per sviluppatori: Docker prune, vecchi node_modules, simulatori e cache dei pacchetti.",
        captionTurboBoost: "Ottimizzazione con 1 clic: libera RAM, sospende le sincronizzazioni e migliora le prestazioni.",
        captionNetworkOptimizer: "Test di latenza e cambio rapido dei server DNS (Cloudflare, Google, Quad9, AdGuard)."
    )

    static let ja = TenFeaturesExtendedStrings(
        titleUninstaller: "完全アンインストーラー",
        titleStartupManager: "スタートアップ管理",
        titleBatteryGuard: "バッテリーヘルスガード",
        titleMiniHUD: "ミニシステムHUD",
        titlePrivacyAuditor: "プライバシー権限監査",
        titleAutoOrganizer: "自動ファイル整理",
        titleFileShredder: "完全データ抹消",
        titleDevDoctor: "開発環境ドクター",
        titleTurboBoost: "ターボ＆ゲームブースト",
        titleNetworkOptimizer: "ネットワーク＆DNS最適化",
        captionUninstaller: "削除済みアプリの残存キャッシュ、設定ファイル、バックグラウンド項目を完全除去。",
        captionStartupManager: "ログイン項目、LaunchAgents、LaunchDaemonsを一覧表示して無効化。",
        captionBatteryGuard: "充放電サイクル、実容量（SoH）、バッテリー温度、充電上限アラートを監視。",
        captionMiniHUD: "CPU、GPU、RAM、ネットワーク速度、チップ温度をリアルタイムで表示するフローティングHUD。",
        captionPrivacyAuditor: "カメラ、マイク、画面収録、ディスクアクセスの権限を監査して不要な許可を取り消し。",
        captionAutoOrganizer: "散らかったデスクトップやダウンロードフォルダをカテゴリごとに自動整理。",
        captionFileShredder: "DoDおよびGutmann規格に基づく完全かつ復元不可能なファイル消去。",
        captionDevDoctor: "Dockerクリーンアップ、不要なnode_modules、Xcodeシミュレータ、パッケージキャッシュを削除。",
        captionTurboBoost: "1クリックで不要なバックグラウンド処理を停止し、RAMを解放してゲームや作業に集中。",
        captionNetworkOptimizer: "Pingとジッターの計測、および高速で安全なDNS（Cloudflare、Google、Quad9）への即時切り替え。"
    )

    static let ko = TenFeaturesExtendedStrings(
        titleUninstaller: "스마트 앱 완전 삭제기",
        titleStartupManager: "시작 프로그램 및 데몬 관리",
        titleBatteryGuard: "배터리 수명 가드",
        titleMiniHUD: "미니 시스템 HUD",
        titlePrivacyAuditor: "개인정보 및 권한 감사",
        titleAutoOrganizer: "자동 파일 정리기",
        titleFileShredder: "보안 파일 완전 분쇄기",
        titleDevDoctor: "개발 환경 닥터",
        titleTurboBoost: "터보 게임 및 집중 모드",
        titleNetworkOptimizer: "네트워크 및 DNS 최적화",
        captionUninstaller: "삭제된 앱의 잔여 캐시, 환경설정, 데몬을 깊숙이 검색하여 완벽하게 제거합니다.",
        captionStartupManager: "로그인 항목, LaunchAgents, LaunchDaemons를 확인하고 비활성화합니다.",
        captionBatteryGuard: "충전 사이클, 배터리 건강 상태(SoH), 실시간 온도 및 충전 리미터 알림을 제공합니다.",
        captionMiniHUD: "CPU, GPU, RAM, 네트워크 속도, 칩 온도를 실시간으로 보여주는 플로팅 미니 모니터.",
        captionPrivacyAuditor: "카메라, 마이크, 전체 디스크 접근 권한을 점검하고 불필요한 권한을 회수합니다.",
        captionAutoOrganizer: "바탕화면과 다운로드 폴더의 파일을 종류별 하위 폴더로 자동 정리합니다.",
        captionFileShredder: "DoD 및 Gutmann 군사 표준에 기반한 복구 불가능한 영구 파일 삭제.",
        captionDevDoctor: "Docker 정리, 방치된 node_modules, Xcode 시뮬레이터 및 패키지 캐시를 정리합니다.",
        captionTurboBoost: "1클릭으로 백그라운드 동기화를 멈추고 RAM을 비워 게임과 고성능 작업에 집중합니다.",
        captionNetworkOptimizer: "지연 시간 측정 및 안전한 DNS(Cloudflare, Google, Quad9) 즉시 전환."
    )

    static let ru = TenFeaturesExtendedStrings(
        titleUninstaller: "Глубокий деинсталлятор",
        titleStartupManager: "Менеджер автозагрузки",
        titleBatteryGuard: "Защита аккумулятора",
        titleMiniHUD: "Мини-монитор HUD",
        titlePrivacyAuditor: "Аудит конфиденциальности",
        titleAutoOrganizer: "Авто-организатор файлов",
        titleFileShredder: "Шредер файлов",
        titleDevDoctor: "Доктор разработчика",
        titleTurboBoost: "Турбо-режим и Игры",
        titleNetworkOptimizer: "Оптимизатор сети и DNS",
        captionUninstaller: "Поиск и удаление скрытых остатков, настроек и демонов удаленных приложений.",
        captionStartupManager: "Управление объектами входа, LaunchAgents и LaunchDaemons.",
        captionBatteryGuard: "Глубокая диагностика батареи: циклы, здоровье (SoH), температура и уведомления.",
        captionMiniHUD: "Плавающий мини-монитор в реальном времени с графиками CPU, GPU, RAM, Сети и Температуры.",
        captionPrivacyAuditor: "Проверка разрешений Камеры, Микрофона и Диска с возможностью отзыва доступа.",
        captionAutoOrganizer: "Автоматическая сортировка файлов на Рабочем столе и в Загрузках по категориям.",
        captionFileShredder: "Необратимое военное уничтожение файлов по стандартам DoD 5220.22-M и Gutmann.",
        captionDevDoctor: "Инструмент для разработчиков: очистка Docker, старых node_modules, симуляторов Xcode и кэшей.",
        captionTurboBoost: "Ускорение в 1 клик: приостановка синхронизаций, очистка RAM и фокус на играх.",
        captionNetworkOptimizer: "Тест пинга и джиттера, быстрое переключение DNS (Cloudflare, Google, Quad9, AdGuard)."
    )

    static let tr = TenFeaturesExtendedStrings(
        titleUninstaller: "Akıllı Uygulama Kaldırıcı",
        titleStartupManager: "Başlangıç ve Arka Plan Yöneticisi",
        titleBatteryGuard: "Pil Sağlığı Koruyucu",
        titleMiniHUD: "Mini Sistem HUD",
        titlePrivacyAuditor: "Gizlilik ve İzin Denetleyicisi",
        titleAutoOrganizer: "Otomatik Dosya Düzenleyici",
        titleFileShredder: "Güvenli Dosya Öğütücü",
        titleDevDoctor: "Geliştirici Doktoru",
        titleTurboBoost: "Turbo Oyun ve Odak Modu",
        titleNetworkOptimizer: "Ağ ve DNS İyileştirici",
        captionUninstaller: "Kaldırılan uygulamaların geride bıraktığı derin önbellek ve daemon kalıntılarını siler.",
        captionStartupManager: "Giriş öğelerini, LaunchAgents ve LaunchDaemons servislerini inceleyin ve devre dışı bırakın.",
        captionBatteryGuard: "Donanım teşhisi: döngü sayısı, pil sağlığı (SoH), sıcaklık ve şarj sınırı bildirimleri.",
        captionMiniHUD: "CPU, GPU, RAM, Ağ ve Sıcaklığı gerçek zamanlı gösteren kayan mini monitör.",
        captionPrivacyAuditor: "Kamera, Mikrofon ve Disk izinlerini denetleyin ve gereksiz izinleri iptal edin.",
        captionAutoOrganizer: "Masaüstü ve İndirilenler klasörlerini kategorilere göre otomatik olarak düzenleyin.",
        captionFileShredder: "DoD ve Gutmann standartlarına uygun, kurtarılamaz kalıcı dosya imhası.",
        captionDevDoctor: "Geliştirici temizliği: Docker prune, eski node_modules, Xcode simülatörleri ve paket önbellekleri.",
        captionTurboBoost: "1 tıkla hızlandırma: arka plan eşitlemelerini durdurur, RAM'i temizler ve oyun performansını artırır.",
        captionNetworkOptimizer: "Gecikme testi ve tek tıkla güvenli DNS geçişi (Cloudflare, Google, Quad9, AdGuard)."
    )

    static let zhHans = TenFeaturesExtendedStrings(
        titleUninstaller: "深度应用程序卸载器",
        titleStartupManager: "开机自启与后台服务管理",
        titleBatteryGuard: "电池健康卫士",
        titleMiniHUD: "悬浮迷你HUD监控",
        titlePrivacyAuditor: "隐私与权限审计",
        titleAutoOrganizer: "桌面与下载自动整理",
        titleFileShredder: "安全文件粉碎器",
        titleDevDoctor: "开发环境体检医生",
        titleTurboBoost: "极速游戏与专注模式",
        titleNetworkOptimizer: "网络与安全DNS优化",
        captionUninstaller: "深度清理已卸载软件在~/Library中的残留配置、缓存和开机守护进程。",
        captionStartupManager: "集中管理和禁用登录项、LaunchAgents与后台LaunchDaemons，加速开机。",
        captionBatteryGuard: "IOKit底层检测：实际充电循环、电池健康度(SoH)、实时温度与80%充电保护提醒。",
        captionMiniHUD: "轻量级实时悬浮窗，显示CPU、GPU、内存、网速和芯片温度微型折线图。",
        captionPrivacyAuditor: "审计摄像头、麦克风、完全磁盘访问权限，一键撤销废弃软件的授权。",
        captionAutoOrganizer: "根据文件类型和时间将杂乱的桌面和下载目录分类归档，支持一键撤销。",
        captionFileShredder: "采用DoD 5220.22-M与Gutmann军工级多重覆写标准，彻底永久粉碎机密文件。",
        captionDevDoctor: "开发者专业清理：Docker一键精简、闲置node_modules清理、Xcode模拟器与包管理缓存。",
        captionTurboBoost: "一键极速优化：暂停云盘后台同步，清空闲置内存，提供游戏和渲染极致性能。",
        captionNetworkOptimizer: "实时延迟与抖动测试，一键无缝切换安全高速DNS(Cloudflare、Google、Quad9、AdGuard)。"
    )

    static let zhTW = TenFeaturesExtendedStrings(
        titleUninstaller: "深度應用程式卸載器",
        titleStartupManager: "開機啟動與背景服務管理",
        titleBatteryGuard: "電池健康衛士",
        titleMiniHUD: "懸浮迷你HUD監控",
        titlePrivacyAuditor: "隱私與權限審計",
        titleAutoOrganizer: "桌面與下載自動整理",
        titleFileShredder: "安全檔案粉碎器",
        titleDevDoctor: "開發環境健檢醫生",
        titleTurboBoost: "極速遊戲與專注模式",
        titleNetworkOptimizer: "網路與安全DNS最佳化",
        captionUninstaller: "深度清理已卸載軟體在~/Library中的殘留設定、快取和開機守護處理程序。",
        captionStartupManager: "集中管理並停用登入項目、LaunchAgents與背景LaunchDaemons，加速開機。",
        captionBatteryGuard: "IOKit底層檢測：實際充電循環、電池健康度(SoH)、即時溫度與80%充電保護提醒。",
        captionMiniHUD: "輕量級即時懸浮視窗，顯示CPU、GPU、記憶體、網速和晶片溫度微型折線圖。",
        captionPrivacyAuditor: "審計攝影機、麥克風、完全磁碟存取權限，一鍵撤銷廢棄軟體的授權。",
        captionAutoOrganizer: "根據檔案類型和時間將雜亂的桌面與下載目錄分類歸檔，支援一鍵還原。",
        captionFileShredder: "採用DoD 5220.22-M與Gutmann軍規級多重覆寫標準，徹底永久粉碎機密檔案。",
        captionDevDoctor: "開發者專業清理：Docker一鍵精簡、閒置node_modules清理、Xcode模擬器與套件快取。",
        captionTurboBoost: "一鍵極速最佳化：暫停雲端硬碟背景同步，清空閒置記憶體，提供遊戲與算圖極致效能。",
        captionNetworkOptimizer: "即時延遲與抖動測試，一鍵無縫切換安全高速DNS(Cloudflare、Google、Quad9、AdGuard)。"
    )

    static let zhHK = TenFeaturesExtendedStrings(
        titleUninstaller: "深度應用程式卸載器",
        titleStartupManager: "開機啟動與後台服務管理",
        titleBatteryGuard: "電池健康衛士",
        titleMiniHUD: "懸浮迷你HUD監控",
        titlePrivacyAuditor: "私隱與權限審計",
        titleAutoOrganizer: "桌面與下載自動整理",
        titleFileShredder: "安全檔案粉碎器",
        titleDevDoctor: "開發環境健檢醫生",
        titleTurboBoost: "極速遊戲與專注模式",
        titleNetworkOptimizer: "網絡與安全DNS優化",
        captionUninstaller: "深度清理已卸載軟件在~/Library中的殘留設定、快取和開機守護進程。",
        captionStartupManager: "集中管理並停用登入項目、LaunchAgents與後台LaunchDaemons，加速開機。",
        captionBatteryGuard: "IOKit底層檢測：實際充電循環、電池健康度(SoH)、即時溫度與80%充電保護提醒。",
        captionMiniHUD: "輕量級即時懸浮視窗，顯示CPU、GPU、記憶體、網速和晶片溫度微型折線圖。",
        captionPrivacyAuditor: "審計鏡頭、咪高峰、完全磁碟存取權限，一鍵撤銷廢棄軟件的授權。",
        captionAutoOrganizer: "根據檔案類型和時間將雜亂的桌面與下載目錄分類歸檔，支援一鍵還原。",
        captionFileShredder: "採用DoD 5220.22-M與Gutmann軍規級多重覆寫標準，徹底永久粉碎機密檔案。",
        captionDevDoctor: "開發者專業清理：Docker一鍵精簡、閒置node_modules清理、Xcode模擬器與套件快取。",
        captionTurboBoost: "一鍵極速優化：暫停雲端硬碟後台同步，清空閒置記憶體，提供遊戲與算圖極致效能。",
        captionNetworkOptimizer: "即時延遲與抖動測試，一鍵無縫切換安全高速DNS(Cloudflare、Google、Quad9、AdGuard)。"
    )
}
