import type {
  BundleDefinition,
  DynamicIslandAgent,
  FeatureDefinition,
  LocaleCode,
  ScratchpadNote,
  SidebarGroupDef,
  TextSnippet,
  VorssaintSettings,
} from '../types/vorssaint';

export const APP_VERSION = '3.7.8';

export const UI_LABELS: Record<LocaleCode, Record<string, string>> = {
  pt: {
    searchSettings: 'Buscar nas configurações',
    featuresHub: 'Central de Recursos',
    featuresTab: 'Recursos',
    permissionsTab: 'Permissões',
    installAll: 'Instalar tudo',
    uninstallAll: 'Remover tudo',
    install: 'Instalar',
    uninstall: 'Remover',
    installedWord: 'instalados',
    applyBundle: 'Aplicar',
    bundlesTitle: 'Começar com um pacote',
    bundlesSub: 'Um clique configura o app para o seu fluxo no Windows.',
    settingsBtn: 'Configurações',
    quitBtn: 'Sair',
    openIsland: 'Expandir Ilha',
    collapseIsland: 'Recolher Ilha',
    sectionsTitle: 'Seções da Ilha',
    commandPlaceholder: 'Pesquisar apps, janelas, cálculos (=), URLs ou ações do Windows...',
  },
  en: {
    searchSettings: 'Search settings',
    featuresHub: 'Features Hub',
    featuresTab: 'Features',
    permissionsTab: 'Permissions',
    installAll: 'Install all',
    uninstallAll: 'Uninstall all',
    install: 'Install',
    uninstall: 'Uninstall',
    installedWord: 'installed',
    applyBundle: 'Apply',
    bundlesTitle: 'Start with a bundle',
    bundlesSub: 'One click configures the app for your Windows workflow.',
    settingsBtn: 'Settings',
    quitBtn: 'Quit',
    openIsland: 'Expand Island',
    collapseIsland: 'Collapse Island',
    sectionsTitle: 'Island Sections',
    commandPlaceholder: 'Search apps, windows, math (=), URLs, or Windows actions...',
  },
  es: {
    searchSettings: 'Buscar en ajustes',
    featuresHub: 'Centro de Funciones',
    featuresTab: 'Funciones',
    permissionsTab: 'Permisos',
    installAll: 'Instalar todo',
    uninstallAll: 'Desinstalar todo',
    install: 'Instalar',
    uninstall: 'Quitar',
    installedWord: 'instaladas',
    applyBundle: 'Aplicar',
    bundlesTitle: 'Comenzar con un paquete',
    bundlesSub: 'Un clic configura la app para tu flujo en Windows.',
    settingsBtn: 'Ajustes',
    quitBtn: 'Salir',
    openIsland: 'Expandir Isla',
    collapseIsland: 'Contraer Isla',
    sectionsTitle: 'Secciones de Isla',
    commandPlaceholder: 'Buscar apps, ventanas, cálculos (=), URLs o acciones de Windows...',
  },
};

export const SIDEBAR_GROUPS: SidebarGroupDef[] = [
  {
    id: 'essentials',
    title: { pt: 'Essenciais', en: 'Essentials', es: 'Esenciales' },
    items: [
      { page: 'general', title: { pt: 'Geral', en: 'General', es: 'General' }, icon: 'sliders' },
      { page: 'features', title: { pt: 'Recursos', en: 'Features', es: 'Funciones' }, icon: 'sparkles' },
      { page: 'panelConfig', title: { pt: 'Painel da Bandeja', en: 'Tray Panel', es: 'Panel de Bandeja' }, icon: 'panelBottom' },
      { page: 'notch', title: { pt: 'Ilha Dinâmica', en: 'Dynamic Island', es: 'Isla Dinámica' }, icon: 'pill' },
      { page: 'notchMascot', title: { pt: 'Mascote da Ilha', en: 'Island Mascot', es: 'Mascota' }, icon: 'bot' },
      { page: 'monitor', title: { pt: 'Monitor do Sistema', en: 'System Monitor', es: 'Monitor' }, icon: 'activity' },
    ],
  },
  {
    id: 'soundEnergy',
    title: { pt: 'Som, Energia & Tela', en: 'Sound, Energy & Display', es: 'Sonido, Energía y Pantalla' },
    items: [
      { page: 'mixer', title: { pt: 'Mixer de Volume por App', en: 'Per-App Volume Mixer', es: 'Mezclador por App' }, icon: 'volume2' },
      { page: 'energy', title: { pt: 'Manter Ligado & Energia', en: 'Keep Awake & Power', es: 'Energía y Suspensión' }, icon: 'zap' },
      { page: 'brightness', title: { pt: 'Brilho & Luz Noturna', en: 'Brightness & Night Light', es: 'Brillo y Luz Nocturna' }, icon: 'sun' },
    ],
  },
  {
    id: 'windowsInput',
    title: { pt: 'Janelas, Atalhos & Texto', en: 'Windows, Shortcuts & Text', es: 'Ventanas, Atajos y Texto' },
    items: [
      { page: 'windowLayout', title: { pt: 'Layout & Snap de Janelas', en: 'Window Layout & Snap', es: 'Diseño de Ventanas' }, icon: 'layoutGrid' },
      { page: 'switcher', title: { pt: 'Alternador de Janelas', en: 'Window Switcher', es: 'Conmutador' }, icon: 'layers' },
      { page: 'commandBar', title: { pt: 'Command Bar (Alt+Space)', en: 'Command Bar (Alt+Space)', es: 'Barra de Comandos' }, icon: 'search' },
      { page: 'radialMenu', title: { pt: 'Menu Radial (Ctrl+Shift+Space)', en: 'Radial Menu', es: 'Menú Radial' }, icon: 'compass' },
      { page: 'shortcuts', title: { pt: 'Atalhos Globais', en: 'Global Shortcuts', es: 'Atajos Globales' }, icon: 'keyboard' },
    ],
  },
  {
    id: 'filesTools',
    title: { pt: 'Arquivos, Dev & Limpeza', en: 'Files, Dev & Cleaning', es: 'Archivos, Dev y Limpieza' },
    items: [
      { page: 'clipboard', title: { pt: 'Histórico da Área de Transferência', en: 'Clipboard History', es: 'Portapapeles' }, icon: 'clipboard' },
      { page: 'shelf', title: { pt: 'Prateleira de Arquivos', en: 'File Shelf', es: 'Estante' }, icon: 'inbox' },
      { page: 'textSnippets', title: { pt: 'Snippets de Texto', en: 'Text Snippets', es: 'Snippets' }, icon: 'fileText' },
      { page: 'urlCleaner', title: { pt: 'Limpador de URLs', en: 'URL Cleaner', es: 'Limpiador URL' }, icon: 'link2' },
      { page: 'screenshot', title: { pt: 'Captura de Tela & Cor', en: 'Screenshot & Color Picker', es: 'Captura y Color' }, icon: 'camera' },
      { page: 'cleaner', title: { pt: 'Limpeza de Caches & Temp', en: 'System Cleaner', es: 'Limpiador' }, icon: 'trash2' },
      { page: 'uninstaller', title: { pt: 'Desinstalador de Apps', en: 'App Uninstaller', es: 'Desinstalador' }, icon: 'packageX' },
      { page: 'appUpdates', title: { pt: 'Atualizações Winget', en: 'Winget Updates', es: 'Actualizaciones Winget' }, icon: 'download' },
      { page: 'portManager', title: { pt: 'Gerenciador de Portas', en: 'Port Manager', es: 'Puertos' }, icon: 'network' },
      { page: 'killProcess', title: { pt: 'Finalizar Processos', en: 'Kill Process', es: 'Procesos' }, icon: 'cpu' },
    ],
  },
  {
    id: 'aboutGroup',
    title: { pt: 'Informações', en: 'About', es: 'Información' },
    items: [
      { page: 'about', title: { pt: 'Sobre o Vorssaint', en: 'About Vorssaint', es: 'Acerca de' }, icon: 'info' },
      { page: 'releaseNotes', title: { pt: 'Notas da Versão', en: 'Release Notes', es: 'Novedades' }, icon: 'fileCheck' },
    ],
  },
];

// Complete 80 AppFeature catalog matching Sources/Vorssaint/Core/FeatureCatalog.swift
export const FEATURE_CATALOG: FeatureDefinition[] = [
  // Dynamic Island (13)
  { key: 'notch', group: 'dynamicIsland', title: { pt: 'Ilha Dinâmica Flutuante', en: 'Floating Dynamic Island', es: 'Isla Dinámica Flotante' }, summary: { pt: 'Pílula interativa no topo do monitor principal do Windows.', en: 'Interactive top-center floating pill on primary monitor.', es: 'Píldora flotante interactiva arriba del monitor.' }, settingsPage: 'notch' },
  { key: 'notchCalendar', group: 'dynamicIsland', title: { pt: 'Agenda na Ilha', en: 'Island Calendar', es: 'Calendario' }, summary: { pt: 'Calendário e eventos rápidos.', en: 'Calendar & upcoming agenda.', es: 'Calendario y eventos.' }, settingsPage: 'notch' },
  { key: 'notchNotifications', group: 'dynamicIsland', title: { pt: 'Avisos na Ilha', en: 'Island Notices', es: 'Avisos' }, summary: { pt: 'Banners compactos de bateria, capturas e alertas.', en: 'Compact banners for battery, captures & alerts.', es: 'Banners compactos en la isla.' }, settingsPage: 'notch' },
  { key: 'notchGestures', group: 'dynamicIsland', title: { pt: 'Gestos da Ilha', en: 'Island Hover & Gestures', es: 'Gestos' }, summary: { pt: 'Expandir ao passar o mouse e arrastar arquivos.', en: 'Hover expand and file drop zone.', es: 'Expandir al pasar el ratón.' }, settingsPage: 'notch' },
  { key: 'notchTimer', group: 'dynamicIsland', title: { pt: 'Timer & Pomodoro na Ilha', en: 'Island Timer & Pomodoro', es: 'Temporizador' }, summary: { pt: 'Contagem regressiva na barra compacta.', en: 'Live countdown strip in compact pill.', es: 'Cuenta regresiva en vivo.' }, settingsPage: 'notch' },
  { key: 'notchAccessories', group: 'dynamicIsland', title: { pt: 'Bateria & Dispositivos', en: 'Power & Connected Devices', es: 'Batería' }, summary: { pt: 'Status de energia AC/Bateria e saúde térmica.', en: 'AC/Battery status & thermal summary.', es: 'Estado de energía.' }, settingsPage: 'notch' },
  { key: 'notchLyrics', group: 'dynamicIsland', title: { pt: 'Mídia & Now Playing', en: 'Now Playing Media Strip', es: 'Reproducción' }, summary: { pt: 'Controles reais de mídia do Windows (Spotify/Navegador).', en: 'Real Windows media playback strip.', es: 'Controles de música reales.' }, settingsPage: 'notch' },
  { key: 'notchQueue', group: 'dynamicIsland', title: { pt: 'Fila de Tarefas & Laps', en: 'Queue & Stopwatch Laps', es: 'Cola y Vueltas' }, summary: { pt: 'Controle sequencial e histórico rápido.', en: 'Queue & stopwatch lap tracking.', es: 'Registro rápido.' }, settingsPage: 'notch' },
  { key: 'notchLiveEqualizer', group: 'dynamicIsland', title: { pt: 'Equalizador Vivo', en: 'Live Equalizer', es: 'Ecualizador Vivo' }, summary: { pt: 'Barras animadas de áudio durante reprodução.', en: 'Animated equalizer bars on active playback.', es: 'Barras animadas de audio.' }, settingsPage: 'notch' },
  { key: 'notchDownloads', group: 'dynamicIsland', title: { pt: 'Monitor de Downloads', en: 'Downloads Strip', es: 'Descargas' }, summary: { pt: 'Acompanhamento de arquivos recebidos na prateleira.', en: 'Dropped & recent files strip.', es: 'Archivos recientes.' }, settingsPage: 'shelf' },
  { key: 'notchAgents', group: 'dynamicIsland', title: { pt: 'Agentes de IA (Claude/Codex/Gemini)', en: 'AI Agents Live Activity', es: 'Agentes IA' }, summary: { pt: 'Acompanhe execuções de agentes direto na pílula.', en: 'Track live AI agent runs in the pill.', es: 'Monitorea agentes de IA.' }, settingsPage: 'notch' },
  { key: 'notchWatch', group: 'dynamicIsland', title: { pt: 'Bloco de Notas na Ilha', en: 'Island Scratchpad & Watch', es: 'Bloc de Notas' }, summary: { pt: 'Notas instantâneas sempre à mão.', en: 'Instant scratchpad accessible from top.', es: 'Notas instantáneas.' }, settingsPage: 'notch' },
  { key: 'notchMascot', group: 'dynamicIsland', title: { pt: 'Mascote Companheiro', en: 'Companion Mascot', es: 'Mascota' }, summary: { pt: 'Rosto interativo que reage ao cursor e arquivos.', en: 'Animated mascot reacting to pointer and drops.', es: 'Mascota animada en la isla.' }, settingsPage: 'notchMascot' },

  // Windows & Taskbar (7)
  { key: 'switcher', group: 'windows', title: { pt: 'Alternador de Janelas', en: 'Window Switcher', es: 'Conmutador' }, summary: { pt: 'Liste, foque e fixe qualquer janela aberta no Windows.', en: 'List, focus, and pin open Windows apps.', es: 'Enfoca ventanas abiertas.' }, settingsPage: 'switcher', shortcut: 'Alt+Space' },
  { key: 'dockPreview', group: 'windows', title: { pt: 'Prévia de Janelas Ativas', en: 'Active Window Inspection', es: 'Vista de Ventanas' }, summary: { pt: 'Visualização detalhada dos processos com janela.', en: 'Inspect active windows across monitors.', es: 'Inspecciona ventanas activas.' }, settingsPage: 'switcher' },
  { key: 'dockClick', group: 'windows', title: { pt: 'Foco & Restauração Rápida', en: 'One-Click Window Restore', es: 'Restaurar Ventana' }, summary: { pt: 'Restaure janelas minimizadas instantaneamente.', en: 'Restore minimized windows with one click.', es: 'Restaura ventanas minimizadas.' }, settingsPage: 'switcher' },
  { key: 'windowMaximizer', group: 'windows', title: { pt: 'Maximizar & Pin Always-on-Top', en: 'Maximize & Always-on-Top Pin', es: 'Maximizar y Fijar' }, summary: { pt: 'Fixe qualquer janela do Windows sempre no topo.', en: 'Toggle real Win32 HWND_TOPMOST on active app.', es: 'Mantén ventanas siempre visibles.' }, settingsPage: 'windowLayout' },
  { key: 'windowLayout', group: 'windows', title: { pt: 'Layout & Snap de Janelas', en: 'Window Layout & Snap', es: 'Diseño de Ventanas' }, summary: { pt: 'Encaixe em metade, quadrantes, terços ou centro.', en: 'Snap target window to halves, quarters, thirds.', es: 'Ajusta ventanas con un clic.' }, settingsPage: 'windowLayout' },
  { key: 'autoQuit', group: 'windows', title: { pt: 'Fechamento Automático de Apps', en: 'Auto-Quit Inactive Apps', es: 'Cierre Automático' }, summary: { pt: 'Encerre processos ociosos com segurança.', en: 'Terminate idle background apps cleanly.', es: 'Cierra apps inactivas.' }, settingsPage: 'killProcess' },
  { key: 'spacesOrder', group: 'windows', title: { pt: 'Preservar Ordem de Telas', en: 'Display Work-Area Layout', es: 'Orden de Pantallas' }, summary: { pt: 'Posicionamento consistente respeitando a barra de tarefas.', en: 'Work-area aware multi-monitor placement.', es: 'Posición consistente.' }, settingsPage: 'windowLayout' },

  // Sound (5)
  { key: 'mixer', group: 'sound', title: { pt: 'Mixer de Volume por App (CoreAudio)', en: 'Per-App CoreAudio Mixer', es: 'Mezclador CoreAudio' }, summary: { pt: 'Controle individual real de volume e mudo por app no Windows.', en: 'Real per-app CoreAudio IAudioSessionManager2 volume & mute.', es: 'Volumen por app en Windows.' }, settingsPage: 'mixer' },
  { key: 'soundOutputSwitcher', group: 'sound', title: { pt: 'Controle Mestre de Áudio', en: 'Master Volume & Mute', es: 'Volumen Maestro' }, summary: { pt: 'Ajuste preciso direto no CoreAudio padrão.', en: 'Direct IAudioEndpointVolume master control.', es: 'Control maestro de audio.' }, settingsPage: 'mixer' },
  { key: 'audioPriority', group: 'sound', title: { pt: 'Prioridade de Áudio', en: 'Audio Priority Rules', es: 'Prioridad de Audio' }, summary: { pt: 'Atenue navegadores durante chamadas.', en: 'Priority volume control per application.', es: 'Reglas de prioridad.' }, settingsPage: 'mixer' },
  { key: 'micMute', group: 'sound', title: { pt: 'Atalho Rápido de Mudo', en: 'Quick Master Mute', es: 'Silencio Rápido' }, summary: { pt: 'Silencie o sistema com um clique no painel ou ilha.', en: 'One-click master mute from pill or tray.', es: 'Silencia en un clic.' }, settingsPage: 'mixer' },
  { key: 'musicBlock', group: 'sound', title: { pt: 'Transporte de Mídia Universal', en: 'Global Media Transport', es: 'Controles Multimedia' }, summary: { pt: 'Play/Pause/Próxima/Anterior nativos no Windows.', en: 'Native Windows VK_MEDIA_* playback controls.', es: 'Controles multimedia nativos.' }, settingsPage: 'mixer' },

  // Energy & Display (4)
  { key: 'keepAwake', group: 'energy', title: { pt: 'Manter Windows Ligado (Keep Awake)', en: 'Keep Windows Awake', es: 'Mantener Despierto' }, summary: { pt: 'Usa SetThreadExecutionState real para impedir suspensão.', en: 'Uses real Win32 SetThreadExecutionState.', es: 'Impide suspensión de Windows.' }, settingsPage: 'energy', shortcut: 'Ctrl+Alt+K' },
  { key: 'brightness', group: 'energy', title: { pt: 'Controle de Brilho WMI', en: 'WMI Display Brightness', es: 'Brillo de Pantalla' }, summary: { pt: 'Ajuste o brilho de tela via WmiMonitorBrightnessMethods.', en: 'Hardware brightness slider via WMI.', es: 'Ajuste real de brillo.' }, settingsPage: 'brightness' },
  { key: 'extraBrightness', group: 'energy', title: { pt: 'Luz Noturna & Conforto Visual', en: 'Night Light & Contrast', es: 'Luz Nocturna' }, summary: { pt: 'Filtro de calor visual configurável.', en: 'Warm display comfort adjustment.', es: 'Filtro nocturno visual.' }, settingsPage: 'brightness' },
  { key: 'bluetoothSleep', group: 'energy', title: { pt: 'Modo Escuro do Windows', en: 'Windows Dark Mode Toggle', es: 'Modo Oscuro Windows' }, summary: { pt: 'Alterne tema claro/escuro do Windows no registro.', en: 'Toggle real Windows HKCU AppsUseLightTheme.', es: 'Tema oscuro del sistema.' }, settingsPage: 'general' },

  // Clipboard & Files (7)
  { key: 'clipboardHistory', group: 'files', title: { pt: 'Histórico do Ctrl+C em Tempo Real', en: 'Real-Time Clipboard History', es: 'Historial Portapapeles' }, summary: { pt: 'Captura automática do portapapeles do Windows via Win32.', en: 'Automatic Win32 GetClipboardSequenceNumber watcher.', es: 'Captura real en segundo plano.' }, settingsPage: 'clipboard', shortcut: 'Ctrl+Shift+V' },
  { key: 'pastePlain', group: 'files', title: { pt: 'Colar / Copiar Texto Limpo', en: 'Plain-Text Copy', es: 'Texto Sin Formato' }, summary: { pt: 'Remove formatação ao enviar de volta ao clipboard.', en: 'Strip rich formatting when copying.', es: 'Elimina formato.' }, settingsPage: 'clipboard' },
  { key: 'finderCutPaste', group: 'files', title: { pt: 'Abrir no Windows Explorer', en: 'Reveal in Explorer', es: 'Abrir en Explorer' }, summary: { pt: 'Acesse rapidamente arquivos, capturas e pastas.', en: 'Open files and captures directly in Explorer.', es: 'Abre archivos en Explorer.' }, settingsPage: 'shelf' },
  { key: 'finderRename', group: 'files', title: { pt: 'Renomeação & Snippets', en: 'Text & Date Templates', es: 'Plantillas de Fecha' }, summary: { pt: 'Snippets rápidos para e-mail, terminal e git.', en: 'Fast text expansions & templates.', es: 'Plantillas rápidas.' }, settingsPage: 'textSnippets' },
  { key: 'shelf', group: 'files', title: { pt: 'Prateleira Drag & Drop na Ilha', en: 'Island File Drop Shelf', es: 'Estante Drag & Drop' }, summary: { pt: 'Arraste qualquer arquivo do Explorer direto para a Ilha.', en: 'Drop real Windows files straight onto top Island.', es: 'Arrastra archivos reales a la Isla.' }, settingsPage: 'shelf' },
  { key: 'urlCleaner', group: 'files', title: { pt: 'Limpador Automático de URLs', en: 'Auto URL Tracking Cleaner', es: 'Limpiador de URLs' }, summary: { pt: 'Remove utm_*, fbclid, gclid, igshid ao copiar links.', en: 'Strip tracking parameters automatically on copy.', es: 'Elimina parámetros utm y rastreo.' }, settingsPage: 'urlCleaner' },
  { key: 'diskImageInstaller', group: 'files', title: { pt: 'Gerenciador Winget', en: 'Winget Package Installer', es: 'Instalador Winget' }, summary: { pt: 'Busque e instale apps do Windows via winget.', en: 'Search and install Windows packages with winget.', es: 'Instala apps vía winget.' }, settingsPage: 'appUpdates' },

  // Utilities (20)
  { key: 'quickLauncher', group: 'utilities', title: { pt: 'Ações Rápidas do Windows', en: 'Quick Windows Launcher', es: 'Lanzador Rápido' }, summary: { pt: 'Explorer, Terminal, Gerenciador de Tarefas e Ajustes.', en: 'Explorer, Windows Terminal, Task Manager, Settings.', es: 'Accesos rápidos de sistema.' }, settingsPage: 'commandBar' },
  { key: 'quickToggles', group: 'utilities', title: { pt: 'Alternadores do Sistema', en: 'Quick System Toggles', es: 'Alternadores Rápidos' }, summary: { pt: 'Tema escuro, Keep Awake, Mudo, Bloquear PC, Lixeira.', en: 'Dark theme, Keep Awake, Mute, Lock PC, Recycle Bin.', es: 'Controles inmediatos.' }, settingsPage: 'panelConfig' },
  { key: 'quitApps', group: 'utilities', title: { pt: 'Encerrar App Instantâneo', en: 'Quick Process Terminate', es: 'Terminar Proceso' }, summary: { pt: 'Finalize processos travados por PID.', en: 'Force terminate frozen tasks by PID.', es: 'Cierra procesos bloqueados.' }, settingsPage: 'killProcess' },
  { key: 'colorPicker', group: 'utilities', title: { pt: 'Conta-gotas Real da Tela', en: 'Native Screen Color Picker', es: 'Cuentagotas de Pantalla' }, summary: { pt: 'Lê o pixel exato sob o cursor Win32 e copia #HEX.', en: 'Sample exact cursor pixel via GDI GetPixel & copy HEX.', es: 'Captura color exacto de pantalla.' }, settingsPage: 'screenshot' },
  { key: 'screenOCR', group: 'utilities', title: { pt: 'Atalho Recorte Windows', en: 'Windows Snipping Shortcut', es: 'Recorte Rápido' }, summary: { pt: 'Inicia a ferramenta nativa de recorte ms-screenclip:.', en: 'Launch native Windows Snipping overlay.', es: 'Abre herramienta de recorte.' }, settingsPage: 'screenshot' },
  { key: 'cleaningMode', group: 'utilities', title: { pt: 'Modo Limpeza de Teclado', en: 'Keyboard Cleaning Lock', es: 'Modo Limpieza' }, summary: { pt: 'Tela cheia segura para limpar teclado e monitor.', en: 'Full-screen lock overlay while wiping keyboard.', es: 'Pantalla segura para limpiar.' }, settingsPage: 'general' },
  { key: 'mediaTools', group: 'utilities', title: { pt: 'Controles de Mídia', en: 'Media Toolkit', es: 'Herramientas Media' }, summary: { pt: 'Controle Play/Pause e faixas na ilha e bandeja.', en: 'Track & playback controls in island & tray.', es: 'Control multimedia.' }, settingsPage: 'mixer' },
  { key: 'cleaner', group: 'utilities', title: { pt: 'Limpador Temp & Caches', en: 'Windows Cache Cleaner', es: 'Limpiador de Caché' }, summary: { pt: 'Escaneia e limpa Temp, Edge, Chrome, CrashDumps e npm.', en: 'Scan & clean Windows Temp, Edge, Chrome & CrashDumps.', es: 'Limpia temporales de Windows.' }, settingsPage: 'cleaner' },
  { key: 'uninstaller', group: 'utilities', title: { pt: 'Desinstalador Completo', en: 'Installed Apps Uninstaller', es: 'Desinstalador Apps' }, summary: { pt: 'Lista programas do Registro e aciona desinstalação.', en: 'Inspect registry apps and launch uninstallers.', es: 'Lista e desinstala programas.' }, settingsPage: 'uninstaller' },
  { key: 'homebrew', group: 'utilities', title: { pt: 'Busca de Pacotes Winget', en: 'Winget Package Search', es: 'Búsqueda Winget' }, summary: { pt: 'Instalação com 1 clique no catálogo oficial Microsoft.', en: 'One-click install from Windows Package Manager.', es: 'Catálogo oficial Winget.' }, settingsPage: 'appUpdates' },
  { key: 'appUpdates', group: 'utilities', title: { pt: 'Atualizações de Programas', en: 'Winget Upgrade Checker', es: 'Actualizaciones' }, summary: { pt: 'Verifica atualizações disponíveis no Windows via winget.', en: 'Check and apply upgrades across Windows apps.', es: 'Busca actualizaciones winget.' }, settingsPage: 'appUpdates' },
  { key: 'screenshot', group: 'utilities', title: { pt: 'Captura de Tela Nativa PNG', en: 'Native Screen Capture PNG', es: 'Captura Pantalla PNG' }, summary: { pt: 'Captura GDI BitBlt salva em Imagens\\Vorssaint.', en: 'Saves real full-screen PNG to Pictures\\Vorssaint.', es: 'Guarda captura PNG real.' }, settingsPage: 'screenshot' },
  { key: 'cameraPreview', group: 'utilities', title: { pt: 'Espelho de Webcam na Ilha', en: 'Island Webcam Mirror', es: 'Espejo de Cámara' }, summary: { pt: 'Prévia rápida da câmera antes de reuniões.', en: 'Instant webcam check before calls.', es: 'Vista previa de webcam.' }, settingsPage: 'notch' },
  { key: 'radialMenu', group: 'utilities', title: { pt: 'Menu Radial Flutuante', en: 'Floating Radial Menu', es: 'Menú Radial' }, summary: { pt: 'Roda de ações rápidas via Ctrl+Shift+Space.', en: 'Action wheel triggered anywhere via Ctrl+Shift+Space.', es: 'Rueda de acciones rápidas.' }, settingsPage: 'radialMenu', shortcut: 'Ctrl+Shift+Space' },
  { key: 'scratchpad', group: 'utilities', title: { pt: 'Bloco de Notas Persistente', en: 'Persistent Scratchpad', es: 'Notas Rápidas' }, summary: { pt: 'Sincronizado automaticamente entre Ilha e Ajustes.', en: 'Auto-synced notes across Island and Settings.', es: 'Notas sincronizadas.' }, settingsPage: 'notch' },
  { key: 'commandBar', group: 'utilities', title: { pt: 'Command Bar Flutuante', en: 'Floating Command Bar', es: 'Barra de Comandos' }, summary: { pt: 'Calculadora (=), janelas, ações e busca com Alt+Space.', en: 'Global Alt+Space launcher with math (=) & window focus.', es: 'Lanzador global Alt+Space.' }, settingsPage: 'commandBar', shortcut: 'Alt+Space' },
  { key: 'screenRecorder', group: 'utilities', title: { pt: 'Atalho Gravador de Tela', en: 'Screen Capture Tools', es: 'Herramientas Captura' }, summary: { pt: 'Acesso direto às capturas recentes em PNG.', en: 'Quick access to recent PNG captures.', es: 'Historial de capturas.' }, settingsPage: 'screenshot' },
  { key: 'wallpaper', group: 'utilities', title: { pt: 'Tema & Acento Visual', en: 'Appearance & Accent Color', es: 'Apariencia y Acento' }, summary: { pt: 'Personalize o visual do app e tema escuro do Windows.', en: 'Customize Vorssaint accent and Windows dark mode.', es: 'Personaliza color y tema.' }, settingsPage: 'general' },
  { key: 'killProcess', group: 'utilities', title: { pt: 'Monitor & Kill de Processos', en: 'Live Process Killer', es: 'Finalizar Procesos' }, summary: { pt: 'Lista processos ordenados por CPU/RAM com encerramento.', en: 'Sort live Windows processes by CPU/RAM and terminate.', es: 'Procesos por CPU y RAM.' }, settingsPage: 'killProcess' },
  { key: 'portManager', group: 'utilities', title: { pt: 'Gerenciador de Portas TCP/UDP', en: 'TCP/UDP Port Manager', es: 'Gestor de Puertos' }, summary: { pt: 'Lê netstat -ano em tempo real e encerra processos por porta.', en: 'Live netstat listening ports & one-click kill.', es: 'Puertos en escucha en vivo.' }, settingsPage: 'portManager' },

  // Monitor (8)
  { key: 'monitorCPU', group: 'monitor', title: { pt: 'Monitor de CPU por Núcleo', en: 'Per-Core CPU Monitor', es: 'Monitor CPU' }, summary: { pt: 'Uso global e matriz em tempo real de todos os núcleos.', en: 'Live global & per-core utilization matrix.', es: 'Uso de CPU por núcleo.' }, settingsPage: 'monitor' },
  { key: 'monitorGPU', group: 'monitor', title: { pt: 'Monitor Térmico & GPU', en: 'Thermal & GPU Monitor', es: 'Monitor GPU y Térmico' }, summary: { pt: 'Sensores de temperatura quando expostos pelo hardware.', en: 'Hardware temperature & GPU telemetry.', es: 'Sensores térmicos.' }, settingsPage: 'monitor' },
  { key: 'monitorMemory', group: 'monitor', title: { pt: 'Monitor de Memória RAM', en: 'Memory Pressure Monitor', es: 'Monitor RAM' }, summary: { pt: 'Uso em GB e nível de pressão da memória.', en: 'Used/total GB and Windows memory pressure.', es: 'Uso y presión de RAM.' }, settingsPage: 'monitor' },
  { key: 'monitorNetwork', group: 'monitor', title: { pt: 'Monitor de Rede RX/TX', en: 'Live Network Monitor', es: 'Monitor de Red' }, summary: { pt: 'Taxas em KB/s e adaptadores ativos no Windows.', en: 'Real-time RX/TX rates across network adapters.', es: 'Tráfico de red en vivo.' }, settingsPage: 'monitor' },
  { key: 'monitorDisk', group: 'monitor', title: { pt: 'Volumes & Discos NTFS', en: 'Disk Volumes Monitor', es: 'Discos NTFS' }, summary: { pt: 'Espaço livre e atalho para abrir cada unidade no Explorer.', en: 'Free space and Explorer shortcut per drive.', es: 'Espacio libre en discos.' }, settingsPage: 'monitor' },
  { key: 'monitorPower', group: 'monitor', title: { pt: 'Energia & Bateria', en: 'Power & Battery Status', es: 'Batería y Energía' }, summary: { pt: 'Leitura direta via Win32 GetSystemPowerStatus.', en: 'Battery level & AC charging via GetSystemPowerStatus.', es: 'Lectura real de batería.' }, settingsPage: 'energy' },
  { key: 'connectedDevices', group: 'monitor', title: { pt: 'Sessões & Periféricos', en: 'Audio & USB Storage', es: 'Dispositivos' }, summary: { pt: 'Dispositivos removíveis e sessões de áudio conectadas.', en: 'Removable drives and active audio endpoints.', es: 'Unidades extraíbles.' }, settingsPage: 'monitor' },
  { key: 'fanControl', group: 'monitor', title: { pt: 'Perfil Térmico & Uptime', en: 'Thermal Curve & Uptime', es: 'Perfil Térmico' }, summary: { pt: 'Tempo ligado e monitoramento contínuo de carga.', en: 'System uptime and continuous load curve.', es: 'Tiempo activo y carga.' }, settingsPage: 'monitor' },

  // Mouse & Keyboard (16 - native Windows equivalents/toggles)
  { key: 'mouseNavigation', group: 'mouse', title: { pt: 'Atalhos Rápidos de Janela', en: 'Window Focus History', es: 'Navegación Rápida' }, summary: { pt: 'Mantém a última janela externa ativa para Snap instantâneo.', en: 'Tracks last foreground external HWND for snapping.', es: 'Seguimiento ventana activa.' }, settingsPage: 'windowLayout' },
  { key: 'textSnippets', group: 'keyboard', title: { pt: 'Biblioteca de Text Snippets', en: 'Text Snippets Library', es: 'Snippets de Texto' }, summary: { pt: 'Modelos prontos com cópia rápida para qualquer campo.', en: 'One-click reusable text templates.', es: 'Plantillas de texto.' }, settingsPage: 'textSnippets' },
  { key: 'superKey', group: 'keyboard', title: { pt: 'Atalhos Globais RegisterHotKey', en: 'Global RegisterHotKey Engine', es: 'Atajos RegisterHotKey' }, summary: { pt: 'Atalhos nativos globais que funcionam em cima de qualquer app.', en: 'Native Win32 global hotkeys active system-wide.', es: 'Atajos globales Win32.' }, settingsPage: 'shortcuts' },
  { key: 'quitWindowProtection', group: 'keyboard', title: { pt: 'Proteção Fechar para Bandeja', en: 'Hide-to-Tray Protection', es: 'Protección Bandeja' }, summary: { pt: 'Fechar a janela principal mantém Ilha e serviços ativos.', en: 'Closing Settings keeps Island and hotkeys running.', es: 'Mantiene app en bandeja.' }, settingsPage: 'general' },
  { key: 'scrollInverter', group: 'mouse', title: { pt: 'Direção de Rolagem Natural', en: 'Natural Scroll Profile', es: 'Scroll Natural' }, summary: { pt: 'Preferência de rolagem do mouse/touchpad.', en: 'Saved scroll preference profile.', es: 'Perfil de desplazamiento.' }, settingsPage: 'general' },
  { key: 'scrollHorizontal', group: 'mouse', title: { pt: 'Rolagem Horizontal Shift+Scroll', en: 'Horizontal Scroll Mode', es: 'Scroll Horizontal' }, summary: { pt: 'Preferência de navegação horizontal.', en: 'Horizontal scroll workflow toggle.', es: 'Modo scroll horizontal.' }, settingsPage: 'general' },
  { key: 'scrollZoom', group: 'mouse', title: { pt: 'Zoom Rápido com Ctrl+Scroll', en: 'Ctrl+Scroll Zoom', es: 'Zoom Ctrl+Scroll' }, summary: { pt: 'Padrão nativo Windows para ampliar interfaces.', en: 'Native Windows Ctrl+Scroll zoom workflow.', es: 'Zoom estándar Windows.' }, settingsPage: 'general' },
  { key: 'focusFollowsMouse', group: 'mouse', title: { pt: 'Foco Inteligente ao Passar Cursor', en: 'Hover Island Auto-Focus', es: 'Foco al Pasar Ratón' }, summary: { pt: 'Expande a Ilha sem roubar o teclado até você clicar.', en: 'Expand Island gently on hover without stealing typing focus.', es: 'Expande Isla sin robar foco.' }, settingsPage: 'notch' },
  { key: 'smoothScroll', group: 'mouse', title: { pt: 'Rolagem Suave na Interface', en: 'Smooth Scroll Physics', es: 'Scroll Suave' }, summary: { pt: 'Transições fluidas em painéis e listas.', en: 'Fluid animations in panels and lists.', es: 'Transiciones fluidas.' }, settingsPage: 'general' },
  { key: 'linearScroll', group: 'mouse', title: { pt: 'Rolagem Linear Precisa', en: 'Linear Wheel Steps', es: 'Scroll Lineal' }, summary: { pt: 'Leitura direta de passos em listas longas.', en: 'Consistent scroll stepping across utilities.', es: 'Pasos lineales.' }, settingsPage: 'general' },
  { key: 'scrollSpeed', group: 'mouse', title: { pt: 'Cadência de Rolagem', en: 'Scroll Cadence', es: 'Velocidad Scroll' }, summary: { pt: 'Configuração de densidade e espaçamento de listas.', en: 'List density & scroll cadence profile.', es: 'Cadencia de listas.' }, settingsPage: 'general' },
  { key: 'mouseAcceleration', group: 'mouse', title: { pt: 'Precisão de Ponteiro', en: 'Pointer Precision Profile', es: 'Precisión Puntero' }, summary: { pt: 'Compatível com Configurações de Mouse do Windows.', en: 'Aligned with Windows pointer precision.', es: 'Precisión del puntero.' }, settingsPage: 'general' },
  { key: 'mouseButtonShortcuts', group: 'mouse', title: { pt: 'Botões de Ação Rápida', en: 'Quick Mouse Actions', es: 'Acciones Ratón' }, summary: { pt: 'Dispare Command Bar ou Radial com clique na bandeja.', en: 'One-click tray & pill shortcuts.', es: 'Accesos con un clic.' }, settingsPage: 'radialMenu' },
  { key: 'middleClick', group: 'mouse', title: { pt: 'Menu Secundário Contextual', en: 'Secondary Context Actions', es: 'Acciones Contextuales' }, summary: { pt: 'Menu nativo direito na bandeja do sistema.', en: 'Right-click Windows System Tray menu.', es: 'Menú bandeja sistema.' }, settingsPage: 'panelConfig' },
  { key: 'mouseClickDebounce', group: 'mouse', title: { pt: 'Proteção Duplo Clique', en: 'Popover Blur Debounce', es: 'Protección Clic' }, summary: { pt: 'Evita fechamento acidental ao abrir o painel na bandeja.', en: 'Prevents accidental flyout dismiss during tray clicks.', es: 'Evita cierre accidental.' }, settingsPage: 'panelConfig' },
  { key: 'keyboardDebounce', group: 'keyboard', title: { pt: 'Atalhos Anti-Repetição', en: 'No-Repeat Hotkey Guard', es: 'Sin Repetición' }, summary: { pt: 'Usa MOD_NOREPEAT no Win32 para evitar múltiplos disparos.', en: 'Uses Win32 MOD_NOREPEAT flag on all global shortcuts.', es: 'Protección MOD_NOREPEAT.' }, settingsPage: 'shortcuts' },
];

export const FEATURE_BUNDLES: BundleDefinition[] = [
  {
    id: 'essential',
    title: { pt: 'Essencial no Windows', en: 'Windows Essentials', es: 'Esenciales Windows' },
    summary: { pt: 'Ilha Dinâmica, Mixer CoreAudio por App, Keep Awake e Monitor do Sistema.', en: 'Dynamic Island, Per-App Mixer, Keep Awake & System Monitor.', es: 'Isla Dinámica, Mezclador, Keep Awake y Monitor.' },
    featureKeys: ['notch', 'notchLyrics', 'notchTimer', 'notchMascot', 'mixer', 'soundOutputSwitcher', 'keepAwake', 'monitorCPU', 'monitorMemory', 'monitorNetwork', 'monitorDisk', 'monitorPower'],
  },
  {
    id: 'windowsProd',
    title: { pt: 'Produtividade & Janelas', en: 'Window Mastery & Productivity', es: 'Productividad' },
    summary: { pt: 'Command Bar (Alt+Space), Menu Radial, Layout Snap, Clipboard Histórico e Limpador URL.', en: 'Command Bar, Radial Menu, Window Snap, Clipboard & URL Cleaner.', es: 'Command Bar, Snap, Portapapeles y URLs.' },
    featureKeys: ['notch', 'notchNotifications', 'notchWatch', 'switcher', 'windowLayout', 'windowMaximizer', 'commandBar', 'radialMenu', 'clipboardHistory', 'urlCleaner', 'textSnippets', 'shelf'],
  },
  {
    id: 'designCapture',
    title: { pt: 'Captura & Design', en: 'Capture & Visual Toolkit', es: 'Captura y Diseño' },
    summary: { pt: 'Captura PNG nativa, Conta-gotas Win32 da tela, Brilho, Webcam na Ilha e Modo Limpeza.', en: 'Native PNG screenshot, Win32 Color Picker, Brightness & Shelf.', es: 'Captura PNG, Cuentagotas y Estante.' },
    featureKeys: ['notch', 'notchGestures', 'shelf', 'screenshot', 'colorPicker', 'cameraPreview', 'brightness', 'cleaningMode', 'quickToggles', 'wallpaper'],
  },
  {
    id: 'devPower',
    title: { pt: 'Developer & Power User', en: 'Developer & Power User', es: 'Desarrollador Avanzado' },
    summary: { pt: 'Port Manager (netstat), Kill Process, Cleaner de Cache, Winget Updates & Agentes na Ilha.', en: 'Port Manager, Kill Process, System Cleaner, Winget & AI Agents.', es: 'Puertos, Procesos, Limpiador y Winget.' },
    featureKeys: FEATURE_CATALOG.map((f) => f.key),
  },
];

export const ISLAND_MODULE_META: {
  id: 'controls' | 'music' | 'files' | 'timer' | 'calendar' | 'clipboard' | 'scratchpad' | 'mixer' | 'camera' | 'agents' | 'system';
  title: Record<LocaleCode, string>;
  shortcut: string;
  accent: string;
}[] = [
  { id: 'controls', title: { pt: 'Controles', en: 'Controls', es: 'Controles' }, shortcut: '1', accent: '#38bdf8' },
  { id: 'music', title: { pt: 'Música', en: 'Now Playing', es: 'Música' }, shortcut: '2', accent: '#f472b6' },
  { id: 'files', title: { pt: 'Arquivos', en: 'File Shelf', es: 'Archivos' }, shortcut: '3', accent: '#fbbf24' },
  { id: 'timer', title: { pt: 'Timer', en: 'Timer', es: 'Tiempo' }, shortcut: '4', accent: '#fb923c' },
  { id: 'clipboard', title: { pt: 'Clipboard', en: 'Clipboard', es: 'Portapapeles' }, shortcut: '5', accent: '#34d399' },
  { id: 'mixer', title: { pt: 'Mixer Apps', en: 'App Mixer', es: 'Mezclador' }, shortcut: '6', accent: '#60a5fa' },
  { id: 'scratchpad', title: { pt: 'Notas', en: 'Scratchpad', es: 'Notas' }, shortcut: '7', accent: '#a78bfa' },
  { id: 'calendar', title: { pt: 'Agenda', en: 'Calendar', es: 'Agenda' }, shortcut: '8', accent: '#f87171' },
  { id: 'system', title: { pt: 'Sistema', en: 'System', es: 'Sistema' }, shortcut: '9', accent: '#2dd4bf' },
  { id: 'camera', title: { pt: 'Webcam', en: 'Camera', es: 'Cámara' }, shortcut: '0', accent: '#c084fc' },
  { id: 'agents', title: { pt: 'Agentes IA', en: 'AI Agents', es: 'Agentes IA' }, shortcut: 'A', accent: '#facc15' },
];

export const INITIAL_NOTES: ScratchpadNote[] = [
  {
    id: 'n1',
    title: 'Vorssaint Windows Shortcuts',
    body: 'Alt+Space  → Command Bar Flutuante\nCtrl+Shift+V → Clipboard Quick Panel\nCtrl+Shift+Space → Menu Radial\nCtrl+Alt+M → Painel da Bandeja\nCtrl+Alt+I → Ilha Dinâmica\nCtrl+Alt+K → Manter Ligado',
    updatedAt: Date.now() - 3600_000,
  },
  {
    id: 'n2',
    title: 'Scratchpad Rápido',
    body: 'Arraste qualquer arquivo do Windows Explorer diretamente sobre a Ilha Dinâmica no topo da tela para guardar aqui na Prateleira.',
    updatedAt: Date.now() - 900_000,
  },
];

export const INITIAL_SNIPPETS: TextSnippet[] = [
  { id: 's1', trigger: ';sig', expansion: 'Atenciosamente,\nAlessandro', category: 'Geral' },
  { id: 's2', trigger: ';ports', expansion: 'netstat -ano | findstr LISTENING', category: 'Dev' },
  { id: 's3', trigger: ';winget', expansion: 'winget upgrade --all --accept-source-agreements', category: 'Dev' },
  { id: 's4', trigger: ';tauri', expansion: 'npx @tauri-apps/cli@2 build --bundles nsis', category: 'Dev' },
];

export const INITIAL_AGENTS: DynamicIslandAgent[] = [
  { id: 'a1', name: 'Claude Code', provider: 'Claude', task: 'Win32 CoreAudio Bridge', status: 'running', elapsedSec: 42 },
  { id: 'a2', name: 'Codex CLI', provider: 'Codex', task: 'Winget Parser Tests', status: 'done', elapsedSec: 18 },
  { id: 'a3', name: 'Gemini CLI', provider: 'Gemini', task: 'Island UI Layout Sync', status: 'waiting', elapsedSec: 9 },
];

export function createDefaultSettings(): VorssaintSettings {
  const installedFeatures: Record<string, boolean> = {};
  for (const f of FEATURE_CATALOG) {
    installedFeatures[f.key] = true;
  }
  return {
    language: 'pt',
    appearance: 'dark',
    accentHex: '#38bdf8',
    islandVisible: true,
    islandPinned: false,
    islandSilhouette: 'pill',
    islandOpenOnHover: true,
    islandMascotEnabled: true,
    islandLiquidGlass: true,
    keepDisplayOn: true,
    brightnessLevel: 85,
    nightLightWarmth: 0,
    autoCleanUrls: true,
    clipboardMaxItems: 80,
    installedFeatures,
    panelVisibleSections: {
      keepAwake: true,
      mixer: true,
      brightness: true,
      system: true,
      network: true,
      disk: true,
      power: true,
      fan: true,
      utilities: true,
      toggles: true,
    },
  };
}
