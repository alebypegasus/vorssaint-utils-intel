import type {
  AppSettings,
  BundleDefinition,
  ClipboardItem,
  DynamicIslandAgent,
  FeatureDefinition,
  LocaleCode,
  MixerAppChannel,
  ScratchpadNote,
  ShelfItem,
  TextSnippet,
} from '../types/vorssaint';

export const APP_VERSION = '3.7.8';

export const UI_STRINGS: Record<LocaleCode, Record<string, string>> = {
  en: {
    featuresHub: 'Features',
    permissions: 'Permissions',
    settingsTitle: 'Vorssaint Settings',
    searchSettings: 'Search settings',
    installedCount: 'features installed',
    installAll: 'Install all',
    uninstallAll: 'Uninstall all',
    install: 'Install',
    uninstall: 'Uninstall',
    applyBundle: 'Apply',
    bundleSection: 'Start with a bundle',
    bundleHint: 'One click sets the app up for how you use Windows. Everything else stays one click away.',
    settingsBtn: 'Settings',
    quitBtn: 'Quit',
    cleanNow: 'Clean Now',
    scanAgain: 'Scan Again',
    commandPlaceholder: 'Search apps, windows, math (=), unit conversions, or actions...',
    islandHint: 'Dynamic Island',
  },
  pt: {
    featuresHub: 'Recursos',
    permissions: 'Permissões',
    settingsTitle: 'Configurações do Vorssaint',
    searchSettings: 'Buscar configurações',
    installedCount: 'recursos instalados',
    installAll: 'Instalar tudo',
    uninstallAll: 'Remover tudo',
    install: 'Instalar',
    uninstall: 'Remover',
    applyBundle: 'Aplicar',
    bundleSection: 'Começar com um pacote',
    bundleHint: 'Um clique adapta o app para o seu Windows. Todo o restante continua acessível.',
    settingsBtn: 'Configurações',
    quitBtn: 'Sair',
    cleanNow: 'Limpar Agora',
    scanAgain: 'Escanear Novamente',
    commandPlaceholder: 'Buscar apps, janelas, cálculos (=), conversões ou ações rápidas...',
    islandHint: 'Ilha Dinâmica',
  },
  es: {
    featuresHub: 'Funciones',
    permissions: 'Permisos',
    settingsTitle: 'Ajustes de Vorssaint',
    searchSettings: 'Buscar ajustes',
    installedCount: 'funciones instaladas',
    installAll: 'Instalar todo',
    uninstallAll: 'Desinstalar todo',
    install: 'Instalar',
    uninstall: 'Desinstalar',
    applyBundle: 'Aplicar',
    bundleSection: 'Empezar con un paquete',
    bundleHint: 'Un clic configura la app para Windows. El resto sigue a un clic de distancia.',
    settingsBtn: 'Ajustes',
    quitBtn: 'Salir',
    cleanNow: 'Limpiar Ahora',
    scanAgain: 'Escanear de nuevo',
    commandPlaceholder: 'Buscar apps, ventanas, cálculos (=), conversiones o acciones...',
    islandHint: 'Isla Dinámica',
  },
};

export const GROUP_LABELS: Record<string, Record<LocaleCode, string>> = {
  windowsDock: { en: 'Windows & Taskbar', pt: 'Janelas e Barra de Tarefas', es: 'Ventanas y Barra' },
  mouseKeyboard: { en: 'Mouse & Keyboard', pt: 'Mouse e Teclado', es: 'Ratón y Teclado' },
  clipboardFiles: { en: 'Clipboard & Explorer', pt: 'Área de Transferência e Arquivos', es: 'Portapapeles y Archivos' },
  sound: { en: 'Sound', pt: 'Som', es: 'Sonido' },
  energyDisplay: { en: 'Energy & Display', pt: 'Energia e Tela', es: 'Energía y Pantalla' },
  tools: { en: 'Tools & Developer', pt: 'Ferramentas e Dev', es: 'Herramientas y Dev' },
  dynamicIsland: { en: 'Dynamic Island', pt: 'Ilha Dinâmica', es: 'Isla Dinámica' },
  monitor: { en: 'System Monitor', pt: 'Monitor do Sistema', es: 'Monitor del Sistema' },
};

function f(
  id: string,
  group: FeatureDefinition['group'],
  icon: string,
  runtimeBadge: FeatureDefinition['runtimeBadge'],
  enName: string,
  ptName: string,
  esName: string,
  enDesc: string,
  ptDesc: string,
  esDesc: string,
  opts: Partial<Pick<FeatureDefinition, 'moduleTab' | 'isBeta' | 'permission' | 'defaultInstalled'>> = {}
): FeatureDefinition {
  return {
    id,
    group,
    icon,
    runtimeBadge,
    name: { en: enName, pt: ptName, es: esName },
    description: { en: enDesc, pt: ptDesc, es: esDesc },
    defaultInstalled: opts.defaultInstalled ?? true,
    moduleTab: opts.moduleTab,
    isBeta: opts.isBeta,
    permission: opts.permission,
  };
}

export const FEATURES_CATALOG: FeatureDefinition[] = [
  // 1. Windows & Taskbar (7)
  f('switcher', 'windowsDock', 'Layers', 'keyboard', 'App switcher', 'Alternador de apps', 'Selector de apps', 'Switch apps and windows with live previews.', 'Alterne entre apps e janelas com prévias ao vivo.', 'Cambia entre apps y ventanas con vistas previas.', { permission: 'accessibility' }),
  f('dockPreview', 'windowsDock', 'Monitor', 'mouse', 'Taskbar Preview', 'Prévia da Barra de Tarefas', 'Vista previa en Barra', 'Live window previews when hovering taskbar apps.', 'Prévias de janelas ao passar o mouse na barra.', 'Vistas previas al pasar el ratón por la barra.', { permission: 'screenRecording' }),
  f('dockClick', 'windowsDock', 'Minimize2', 'mouse', 'Taskbar clicks', 'Cliques na Barra', 'Clics en Barra', 'Click taskbar icons to minimize or cycle windows.', 'Clique na barra para minimizar ou alternar janelas.', 'Haz clic en la barra para minimizar o rotar ventanas.', { permission: 'accessibility' }),
  f('windowMaximizer', 'windowsDock', 'Maximize2', 'mouse', 'Maximize windows', 'Maximizar janelas', 'Maximizar ventanas', 'Double-click or titlebar action maximizes cleanly.', 'Maximiza janelas respeitando a área útil do Windows.', 'Maximiza ventanas dentro del área de trabajo.', { permission: 'accessibility' }),
  f('windowLayout', 'windowsDock', 'LayoutGrid', 'keyboard', 'Window layout', 'Layout de janelas', 'Diseño de ventanas', 'Snap active windows into halves, thirds, or corners.', 'Organize janelas em metades, terços ou cantos.', 'Ajusta ventanas en mitades, tercios o esquinas.', { permission: 'accessibility' }),
  f('autoQuit', 'windowsDock', 'XSquare', 'idle', 'Quit on close', 'Fechar ao encerrar janela', 'Cerrar al último', 'Automatically terminates background apps on last window close.', 'Encerra processos em segundo plano ao fechar a última janela.', 'Cierra apps al cerrar la última ventana.' ),
  f('spacesOrder', 'windowsDock', 'Columns3', 'keyboard', 'Virtual Desktops Order', 'Ordem das Áreas Virtuais', 'Orden de Escritorios', 'Preserve deterministic Win+Ctrl virtual desktop ordering.', 'Mantém ordem consistente nas Áreas de Trabalho Virtuais.', 'Mantiene orden fijo de Escritorios Virtuales.'),

  // 2. Mouse & Keyboard (16)
  f('scrollInverter', 'mouseKeyboard', 'ArrowUpDown', 'mouse', 'Reverse scrolling', 'Inverter rolagem', 'Invertir desplazamiento', 'Separate natural/classic wheel direction from touchpad.', 'Direção independente para roda do mouse e touchpad.', 'Dirección separada para ratón y panel táctil.'),
  f('scrollHorizontal', 'mouseKeyboard', 'ArrowLeftRight', 'mouse', 'Horizontal scroll', 'Rolagem horizontal', 'Desplazamiento horizontal', 'Hold Shift + wheel for crisp horizontal scrolling.', 'Segure Shift + scroll para rolar horizontalmente.', 'Mantén Shift + rueda para desplazar horizontalmente.'),
  f('scrollZoom', 'mouseKeyboard', 'ZoomIn', 'mouse', 'Scroll zoom', 'Zoom com scroll', 'Zoom con rueda', 'Smooth pinch/wheel zoom modifier anywhere on Windows.', 'Zoom suave com modificador + rolagem em qualquer app.', 'Zoom suave con modificador y rueda.'),
  f('focusFollowsMouse', 'mouseKeyboard', 'MousePointer', 'mouse', 'Focus follows mouse', 'Foco segue o mouse', 'El foco sigue al ratón', 'Automatically focuses the window under the cursor.', 'Ativa automaticamente a janela sob o cursor.', 'Enfoca automáticamente la ventana bajo el cursor.'),
  f('smoothScroll', 'mouseKeyboard', 'Waves', 'mouse', 'Smooth scrolling', 'Rolagem suave', 'Desplazamiento fluido', 'Interpolated 120Hz wheel smoothing curve.', 'Curva interpolada de rolagem suave.', 'Curva fluida para rueda del ratón.'),
  f('linearScroll', 'mouseKeyboard', 'AlignJustify', 'mouse', 'Linear wheel step', 'Rolagem linear fixa', 'Desplazamiento lineal', 'Consistent predictable scroll lines per wheel notch.', 'Passo fixo por clique da roda do mouse.', 'Paso uniforme por giro de rueda.'),
  f('scrollSpeed', 'mouseKeyboard', 'Gauge', 'mouse', 'Scroll speed', 'Velocidade do scroll', 'Velocidad de rueda', 'Per-axis multiplier for wheel responsiveness.', 'Multiplicador fino para velocidade da rolagem.', 'Multiplicador de velocidad de desplazamiento.'),
  f('mouseAcceleration', 'mouseKeyboard', 'Crosshair', 'mouse', 'Disable pointer acceleration', 'Desativar aceleração do mouse', 'Desactivar aceleración', 'Raw 1:1 linear pointer curve without Windows EPP curve.', 'Curva linear 1:1 sem aceleração imprecisa.', 'Curva lineal 1:1 sin aceleración de Windows.'),
  f('mouseNavigation', 'mouseKeyboard', 'Navigation', 'mouse', 'Mouse back/forward', 'Navegação por botões', 'Navegación con ratón', 'Bind extra mouse side buttons to Back/Forward universally.', 'Mapeia botões laterais para Voltar/Avançar.', 'Asigna botones laterales para Atrás/Adelante.'),
  f('mouseButtonShortcuts', 'mouseKeyboard', 'Mouse', 'mouse', 'Mouse button shortcuts', 'Atalhos nos botões do mouse', 'Atajos de botones', 'Assign custom shortcuts to extra mouse buttons.', 'Execute ações e atalhos com botões extras.', 'Asigna acciones a botones adicionales del ratón.'),
  f('middleClick', 'mouseKeyboard', 'Pointer', 'mouse', 'Middle click action', 'Ação de clique do meio', 'Clic central', 'Open links, close tabs, or trigger Quick Panel on middle click.', 'Abre links ou fecha abas com clique central.', 'Abre enlaces o cierra pestañas con clic central.'),
  f('mouseClickDebounce', 'mouseKeyboard', 'ShieldAlert', 'mouse', 'Mouse debounce filter', 'Filtro anti-duplo clique', 'Filtro antirrebote ratón', 'Blocks unintended double clicks on aging mouse switches.', 'Ignora cliques duplos acidentais em switches gastos.', 'Filtra clics dobles involuntarios.'),
  f('keyboardDebounce', 'mouseKeyboard', 'Keyboard', 'keyboard', 'Keyboard chatter filter', 'Filtro anti-repetição (Chatter)', 'Filtro de teclado', 'Suppresses mechanical key bounce duplicates.', 'Suprime digitação duplicada em teclados mecânicos.', 'Evita pulsaciones dobles mecánicas.'),
  f('textSnippets', 'mouseKeyboard', 'FileText', 'keyboard', 'Text snippets', 'Trechos de texto', 'Fragmentos de texto', 'Expand short triggers like ;sig or ;addr into full blocks.', 'Expande atalhos como ;sig ou ;mail em textos completos.', 'Expande abreviaturas en bloques completos.'),
  f('superKey', 'mouseKeyboard', 'Command', 'keyboard', 'Super Key layer', 'Camada Super Key', 'Capa Super Key', 'Turn CapsLock into Hyper or App Launcher key.', 'Transforma CapsLock em tecla de atalho ou Hyper.', 'Convierte CapsLock en tecla Hyper.'),
  f('quitWindowProtection', 'mouseKeyboard', 'ShieldCheck', 'keyboard', 'Hold to close guard', 'Proteção contra fechar acidental', 'Protección al cerrar', 'Require holding Alt+F4 briefly before closing critical apps.', 'Exige pressionar brevemente antes de encerrar o app.', 'Requiere mantener pulsado para cerrar.'),

  // 3. Clipboard & Explorer (7)
  f('clipboardHistory', 'clipboardFiles', 'Clipboard', 'idle', 'Clipboard history', 'Histórico de Transferência', 'Historial de Portapapeles', 'Local encrypted history with pin & search support.', 'Histórico local pesquisável com itens fixados.', 'Historial local con búsqueda y fijado.'),
  f('pastePlain', 'clipboardFiles', 'Type', 'keyboard', 'Paste as plain text', 'Colar sem formatação', 'Pegar texto sin formato', 'Strip fonts and colors before pasting with Ctrl+Shift+V.', 'Remove estilos antes de colar no Windows.', 'Elimina formato y colores al pegar.'),
  f('finderCutPaste', 'clipboardFiles', 'Scissors', 'idle', 'Explorer quick actions', 'Ações rápidas do Explorer', 'Acciones de Explorador', 'Cut, copy path, and paste image directly as PNG.', 'Recortar, copiar caminho e colar imagens como arquivo.', 'Cortar, copiar ruta y pegar imagen como archivo.'),
  f('finderRename', 'clipboardFiles', 'Edit3', 'idle', 'Batch rename', 'Renomear em lote', 'Renombrado masivo', 'Regex, numbering, and date templates for selected files.', 'Renomeação com padrões de numeração e regex.', 'Renombrado múltiple con patrones.'),
  f('shelf', 'clipboardFiles', 'Inbox', 'idle', 'Floating File Shelf', 'Prateleira Flutuante de Arquivos', 'Estante de Archivos', 'Temporary drag-and-drop dropzone across virtual desktops.', 'Área flutuante para arrastar e soltar entre janelas.', 'Zona flotante temporal para arrastrar archivos.'),
  f('urlCleaner', 'clipboardFiles', 'Link2', 'idle', 'Clean URLs', 'Limpar URLs', 'Limpiar URLs', 'Automatically strip utm_*, fbclid, and gclid trackers.', 'Remove parâmetros utm_*, fbclid e gclid de links.', 'Elimina parámetros de rastreo de enlaces.'),
  f('diskImageInstaller', 'clipboardFiles', 'HardDriveDownload', 'idle', 'Package / ISO Quick Mount', 'Montagem rápida de ISO/MSI', 'Montaje rápido ISO', 'Inspect archives, ISO images, and installers cleanly.', 'Inspeciona ISOs, ZIPs e instaladores sem ruído.', 'Inspecciona ISOs e instaladores rápidamente.'),

  // 4. Sound (5)
  f('mixer', 'sound', 'Sliders', 'audio', 'Volume Mixer', 'Mixer de Volume por App', 'Mezclador de Volumen', 'Per-app volume faders with >100% Boost and device routing.', 'Volume individual por app, Boost >100% e seleção de saída.', 'Volumen por app, Boost >100% y salida por app.', { moduleTab: 'mixer', permission: 'audioCapture' }),
  f('soundOutputSwitcher', 'sound', 'Speaker', 'audio', 'Output Switcher', 'Alternador de Saída', 'Selector de Salida', 'Switch speakers, headphones, and HDMI audio in one click.', 'Alterne entre caixas, fones e HDMI em um clique.', 'Cambia altavoces y auriculares al instante.'),
  f('audioPriority', 'sound', 'ListOrdered', 'audio', 'Device Priority', 'Prioridade de Áudio', 'Prioridad de Dispositivos', 'Lock your preferred mic and headset order automatically.', 'Mantém ordem automática de fones e microfones.', 'Prioridad automática de micrófonos y salidas.'),
  f('micMute', 'sound', 'MicOff', 'audio', 'Mic Mute Toggle', 'Silenciar Microfone Global', 'Silenciar Micrófono', 'Instant system-wide hotkey to mute/unmute microphone.', 'Atalho global imediato para mutar o microfone.', 'Atajo global para silenciar el micrófono.', { permission: 'microphone' }),
  f('musicBlock', 'sound', 'Music', 'audio', 'Media Auto-Launch Blocker', 'Bloqueio de Auto-Play', 'Bloqueo Auto-Play', 'Prevent headset buttons from unexpectedly launching media players.', 'Impede que botões do fone abram players indesejados.', 'Evita apertura accidental de reproductores.'),

  // 5. Energy & Display (4)
  f('keepAwake', 'energyDisplay', 'Moon', 'idle', 'Keep Awake', 'Manter Acordado', 'Mantener Activo', 'Native Win32 SetThreadExecutionState to prevent sleep/dimming.', 'Usa SetThreadExecutionState nativo do Windows contra suspensão.', 'Evita suspensión de pantalla y sistema.', { moduleTab: 'keepAwake' }),
  f('brightness', 'energyDisplay', 'Sun', 'idle', 'Display Brightness & Warmth', 'Brilho e Temperatura de Cor', 'Brillo y Calidez', 'WMI/DDC hardware brightness + warm night filter slider.', 'Controle de brilho WMI/DDC e filtro noturno.', 'Brillo hardware WMI y filtro nocturno.', { moduleTab: 'brightness' }),
  f('extraBrightness', 'energyDisplay', 'SunMedium', 'idle', 'Software Dimming & Extra Boost', 'Dimmer extra e Contraste', 'Brillo extendido', 'Go below minimum hardware backlight in dark rooms.', 'Reduz brilho abaixo do mínimo padrão à noite.', 'Atenuación adicional para cuartos oscuros.', { moduleTab: 'brightness' }),
  f('bluetoothSleep', 'energyDisplay', 'Bluetooth', 'idle', 'Power & Sleep Policies', 'Políticas de Bluetooth/Energia', 'Energía Bluetooth', 'Keep wireless peripherals and battery saver balanced.', 'Gerencia planos de energia e periféricos Bluetooth.', 'Controla energía y periféricos inalámbricos.'),

  // 6. Tools & Developer (20)
  f('quickLauncher', 'tools', 'Grid', 'idle', 'Quick Panel', 'Painel Rápido', 'Panel Rápido', 'Instant shortcut popup for favorite Windows tools.', 'Painel flutuante com atalhos e ações favoritas.', 'Panel flotante con accesos directos.'),
  f('quickToggles', 'tools', 'ToggleRight', 'idle', 'Quick Controls', 'Controles Rápidos', 'Controles Rápidos', 'Collapsible controls tab inside the tray panel.', 'Aba de alternadores rápidos direto no painel.', 'Controles rápidos dentro del panel.', { moduleTab: 'controls' }),
  f('quitApps', 'tools', 'Power', 'idle', 'Quit Running Apps', 'Encerrar Apps Abertos', 'Cerrar Apps Activas', 'Close distracting or hung desktop apps at once.', 'Encerre múltiplos aplicativos ou processos travados.', 'Cierra apps múltiples al instante.'),
  f('colorPicker', 'tools', 'Pipette', 'idle', 'Color Picker', 'Seletor de Cor', 'Selector de Color', 'Inspect any pixel HEX, RGB, or HSL and copy immediately.', 'Capture códigos HEX, RGB e HSL da tela.', 'Captura HEX, RGB y HSL de pantalla.'),
  f('screenOCR', 'tools', 'ScanText', 'idle', 'Copy text from screen (OCR)', 'Copiar texto da tela (OCR)', 'Texto desde pantalla (OCR)', 'Extract selectable text from any image, video, or window.', 'Extrai texto de imagens ou vídeos direto para a área.', 'Extrae texto de capturas o videos.'),
  f('cleaningMode', 'tools', 'Sparkles', 'idle', 'Keyboard Cleaning Mode', 'Modo Limpeza de Teclado', 'Modo Limpieza', 'Full-screen input lock with hold-to-unlock progress.', 'Bloqueia teclado e touchpad para limpeza segura.', 'Bloquea teclado para limpieza segura.'),
  f('mediaTools', 'tools', 'Image', 'idle', 'Media Compression & GIFs', 'Compressor de Mídia & GIF', 'Herramientas Multimedia', 'Compress screenshots, videos, and convert MP4 to GIF locally.', 'Comprime imagens/vídeos e gera GIFs localmente.', 'Comprime videos e imágenes localmente.'),
  f('cleaner', 'tools', 'Trash2', 'idle', 'System Cleaner', 'Limpeza de Sistema', 'Limpiador del Sistema', 'Scans %TEMP%, CrashDumps, npm/pip caches and logs safely.', 'Analisa e limpa %TEMP%, CrashDumps, caches npm/pip.', 'Limpia %TEMP%, volcados y cachés locales.'),
  f('uninstaller', 'tools', 'PackageMinus', 'idle', 'App Uninstaller', 'Desinstalador Completo', 'Desinstalador', 'Lists Registry apps and triggers native uninstallers cleanly.', 'Lista apps do Registro do Windows com desinstalação rápida.', 'Lista apps instaladas y desinstaladores.', { permission: 'appManagement' }),
  f('homebrew', 'tools', 'Package', 'idle', 'Winget Package Manager', 'Gerenciador Winget', 'Gestor Winget', 'Search, install, and upgrade Windows packages via winget.', 'Busque, instale e atualize pacotes Windows com winget.', 'Busca e instala paquetes con winget.'),
  f('appUpdates', 'tools', 'DownloadCloud', 'idle', 'App Updates Tracker', 'Atualizações de Apps', 'Actualizaciones', 'Scan outdated Windows packages and upgrade cleanly.', 'Detecta e aplica atualizações disponíveis via winget.', 'Detecta actualizaciones disponibles.'),
  f('screenshot', 'tools', 'Camera', 'idle', 'Screenshot Studio', 'Estúdio de Captura', 'Estudio de Captura', 'Region, window, full screen, and scrolling screenshot workflow.', 'Captura área, janela, tela inteira ou rolagem.', 'Capturas de región, ventana o desplazamiento.', { permission: 'screenRecording' }),
  f('cameraPreview', 'tools', 'Video', 'idle', 'Webcam Mirror', 'Espelho de Webcam', 'Espejo de Cámara', 'Quick lighting and framing check inside the Dynamic Island.', 'Conferência rápida de câmera e iluminação antes de reuniões.', 'Vista previa rápida de cámara.', { permission: 'camera' }),
  f('radialMenu', 'tools', 'Disc', 'mouse', 'Radial Menu', 'Menu Radial', 'Menú Radial', 'Circular cursor-centered quick action wheel.', 'Roda interativa ao redor do cursor para ações rápidas.', 'Rueda circular rápida alrededor del cursor.'),
  f('scratchpad', 'tools', 'StickyNote', 'idle', 'Floating Scratchpad', 'Bloco de Notas Flutuante', 'Bloc de Notas', 'Multi-tab Markdown scratchpad with live preview.', 'Notas rápidas com múltiplas abas e Markdown.', 'Notas rápidas con pestañas y Markdown.'),
  f('commandBar', 'tools', 'Search', 'keyboard', 'Command Bar (Ctrl+K)', 'Barra de Comandos (Ctrl+K)', 'Barra de Comandos', 'Instant search across apps, windows, math, and conversions.', 'Busque apps, janelas abertas, cálculos e conversões.', 'Busca apps, ventanas, cálculos y unidades.'),
  f('screenRecorder', 'tools', 'CircleDot', 'idle', 'Screen Recorder', 'Gravador de Tela', 'Grabador de Pantalla', 'Record MP4/GIF with optional keystroke and cursor highlights.', 'Grave a tela em MP4/GIF com destaque de teclas e cursor.', 'Graba pantalla en MP4/GIF con teclas visibles.', { permission: 'screenRecording' }),
  f('wallpaper', 'tools', 'Wallpaper', 'idle', 'Wallpaper Studio', 'Estúdio de Papel de Parede', 'Fondos de Pantalla', 'Curated studio presets and live Windows desktop themes.', 'Coleção selecionada de fundos escuros e dinâmicos.', 'Galería curada de fondos de escritorio.', { moduleTab: 'wallpaper' }),
  f('killProcess', 'tools', 'OctagonX', 'idle', 'Kill Process', 'Encerrar Processo (PID)', 'Finalizar Proceso', 'Find heavy or frozen executables and terminate immediately.', 'Localize processos travados e encerre por PID.', 'Encuentra y cierra procesos congelados.', { isBeta: true }),
  f('portManager', 'tools', 'Network', 'idle', 'Port Manager', 'Gerenciador de Portas', 'Gestor de Puertos', 'Inspect live TCP/UDP listening sockets via netstat and free ports.', 'Veja portas TCP/UDP abertas e encerre processos em conflito.', 'Inspecciona puertos activos TCP/UDP.'),

  // 7. Dynamic Island (13)
  f('notch', 'dynamicIsland', 'Sparkle', 'idle', 'Dynamic Island Bar', 'Barra Ilha Dinâmica', 'Barra Isla Dinámica', 'Always-accessible floating HUD pill for media, timers, and agents.', 'Pílula flutuante no topo para mídia, timers e agentes de IA.', 'Cápsula superior interactiva en Windows.'),
  f('notchCalendar', 'dynamicIsland', 'Calendar', 'idle', 'Calendar Agenda', 'Agenda na Ilha', 'Calendario en Isla', 'View upcoming meetings directly inside the Dynamic Island.', 'Próximos compromissos direto na Ilha Dinâmica.', 'Reuniones próximas en la Isla.', { permission: 'calendar' }),
  f('notchNotifications', 'dynamicIsland', 'Bell', 'idle', 'Island Notifications', 'Notificações na Ilha', 'Notificaciones en Isla', 'Compact non-intrusive toast mirror inside the pill.', 'Central limpa de alertas dentro da Ilha.', 'Alertas limpias en la Isla.', { permission: 'notifications' }),
  f('notchGestures', 'dynamicIsland', 'Hand', 'mouse', 'Island Hover & Gestures', 'Gestos na Ilha', 'Gestos en Isla', 'Expand on hover or swipe tabs seamlessly.', 'Expansão suave ao passar o mouse e troca de abas.', 'Expansión al pasar el cursor.'),
  f('notchTimer', 'dynamicIsland', 'Timer', 'idle', 'Countdown & Pomodoro', 'Timer e Pomodoro', 'Temporizador', 'Live countdown pill visible across full-screen workspaces.', 'Cronômetro regressivo com presets 5m, 15m e 25m.', 'Temporizador visible sobre todo.'),
  f('notchAccessories', 'dynamicIsland', 'Headphones', 'idle', 'Accessory Battery', 'Bateria de Periféricos', 'Batería de Accesorios', 'Track Bluetooth mouse, headset, and keyboard battery.', 'Exibe carga de fone, teclado e mouse Bluetooth.', 'Muestra batería de periféricos.'),
  f('notchLyrics', 'dynamicIsland', 'Quote', 'idle', 'Synchronized Lyrics', 'Letras em Tempo Real', 'Letras en Vivo', 'Follow along with live song lyrics in the expanded island.', 'Mostra letras sincronizadas no player da Ilha.', 'Letras en directo en la Isla.'),
  f('notchQueue', 'dynamicIsland', 'ListMusic', 'idle', 'Up Next Queue', 'Fila de Reprodução', 'Cola de Reproducción', 'Preview and skip upcoming tracks right from the pill.', 'Visualize e avance faixas da fila rapidamente.', 'Vista rápida de la cola musical.'),
  f('notchLiveEqualizer', 'dynamicIsland', 'AudioLines', 'audio', 'Live Audio Equalizer', 'Equalizador Animado', 'Ecualizador en Vivo', 'Responsive waveform visualizer synced to playback.', 'Barras reativas sincronizadas com o áudio.', 'Visualizador reactivo de audio.'),
  f('notchDownloads', 'dynamicIsland', 'Download', 'idle', 'Downloads & File Drop', 'Downloads e Arraste', 'Descargas en Isla', 'Track active downloads and drop files directly onto the pill.', 'Acompanhe downloads e solte arquivos na Ilha.', 'Sigue descargas y suelta archivos.'),
  f('notchAgents', 'dynamicIsland', 'Bot', 'idle', 'AI Coding Agents Monitor', 'Monitor de Agentes de IA', 'Monitor de Agentes IA', 'Track active Claude Code, Codex, and Copilot sessions live.', 'Acompanhe sessões Claude, Codex e Copilot e uso de tokens.', 'Supervisa sesiones Claude, Codex y Copilot.'),
  f('notchWatch', 'dynamicIsland', 'Eye', 'idle', 'Area Watcher', 'Monitor de Área Visual', 'Vigilante de Área', 'Watch a region of the screen for build/deploy state changes.', 'Monitora região da tela esperando conclusão de build.', 'Vigila cambios en una zona de la pantalla.'),
  f('notchMascot', 'dynamicIsland', 'Smile', 'idle', 'Vorssaint Companion', 'Mascote Vorssaint', 'Mascota Vorssaint', 'Interactive orbital planet buddy perched on the island edge.', 'Companheiro orbital discreto na borda da Ilha.', 'Acompañante discreto en el borde de la Isla.'),

  // 8. System Monitor (8)
  f('monitorCPU', 'monitor', 'Cpu', 'idle', 'CPU & Core Matrix', 'CPU e Núcleos', 'CPU y Núcleos', 'Real-time per-core graph, package temp, and top processes.', 'Carga geral e por núcleo, temperatura e ranking de processos.', 'Carga por núcleo, temperatura y procesos.', { moduleTab: 'system' }),
  f('monitorGPU', 'monitor', 'Activity', 'idle', 'GPU Telemetry', 'Telemetria GPU', 'Telemetría GPU', 'Graphics utilization and thermal tracking.', 'Acompanhe carga gráfica e temperatura.', 'Uso y temperatura gráfica.', { moduleTab: 'system' }),
  f('monitorMemory', 'monitor', 'MemoryStick', 'idle', 'Memory Pressure', 'Uso e Pressão de RAM', 'Presión de Memoria', 'Physical RAM allocation with Normal/Warn/Critical badge.', 'Uso de memória física com indicador Normal/Alto/Crítico.', 'Uso de RAM con indicador de estado.', { moduleTab: 'system' }),
  f('monitorNetwork', 'monitor', 'Wifi', 'idle', 'Network Speed & Adapters', 'Rede e Adaptadores', 'Red y Adaptadores', 'Real-time RX/TX speeds across Wi-Fi and Ethernet.', 'Taxas de download/upload em tempo real por adaptador.', 'Velocidad RX/TX por adaptador.', { moduleTab: 'network' }),
  f('monitorDisk', 'monitor', 'HardDrive', 'idle', 'Disk & Storage Space', 'Discos e Armazenamento', 'Discos y Almacenamiento', 'Live NTFS/NVMe drive usage and free GB capacity.', 'Espaço livre e percentual usado de todas as partições.', 'Espacio usado y disponible por unidad.', { moduleTab: 'disk' }),
  f('monitorPower', 'monitor', 'Zap', 'idle', 'Battery & Power Status', 'Energia e Bateria', 'Energía y Batería', 'AC line status, charge percentage, and battery temperature.', 'Monitoramento de carga, tomada AC e temperatura da bateria.', 'Estado AC, carga y temperatura.', { moduleTab: 'power' }),
  f('connectedDevices', 'monitor', 'Usb', 'idle', 'Connected Devices', 'Dispositivos Conectados', 'Dispositivos Conectados', 'Inspect active audio, display, and USB devices.', 'Visão unificada de dispositivos de som, vídeo e USB.', 'Resumen de dispositivos conectados.'),
  f('fanControl', 'monitor', 'Fan', 'idle', 'Thermal & Fan Profiles', 'Controle Térmico e Fans', 'Control de Ventiladores', 'Switch between Silent, Balanced, and Performance cooling.', 'Perfis Silencioso, Balanceado e Performance para ventoinhas.', 'Perfiles de ventilación y RPM.', { moduleTab: 'fanControl', isBeta: true }),
];

export const BUNDLES: BundleDefinition[] = [
  {
    id: 'essentials',
    name: { en: 'Essentials', pt: 'Essenciais', es: 'Esenciales' },
    description: {
      en: 'Volume mixer, system monitor, command bar and keep awake.',
      pt: 'Mixer de volume, monitor do sistema, barra de comandos e manter acordado.',
      es: 'Mezclador, monitor, barra de comandos y mantener activo.',
    },
    icon: 'Star',
    featureIds: ['mixer', 'monitorCPU', 'monitorMemory', 'monitorNetwork', 'monitorDisk', 'monitorPower', 'keepAwake', 'brightness', 'commandBar', 'clipboardHistory', 'cleaner', 'quickToggles', 'notch', 'notchTimer'],
  },
  {
    id: 'windows',
    name: { en: 'Windows Productivity', pt: 'Produtividade Windows', es: 'Productividad Windows' },
    description: {
      en: 'App switcher, window layout snapping, taskbar clicks and quick shelf.',
      pt: 'Alternador, snap de janelas, cliques na barra de tarefas e prateleira.',
      es: 'Selector, ajuste de ventanas, barra de tareas y estante.',
    },
    icon: 'AppWindow',
    featureIds: ['switcher', 'dockPreview', 'dockClick', 'windowMaximizer', 'windowLayout', 'autoQuit', 'shelf', 'clipboardHistory', 'pastePlain', 'finderCutPaste', 'quickLauncher', 'quickToggles', 'radialMenu', 'scratchpad'],
  },
  {
    id: 'battery',
    name: { en: 'Battery & Quiet', pt: 'Bateria e Silêncio', es: 'Batería y Silencio' },
    description: {
      en: 'Lean system telemetry with battery, memory, and processor. No input hooks.',
      pt: 'Monitor leve com bateria, memória e processador. Sem escuta de teclado.',
      es: 'Monitor ligero con batería, memoria y procesador. Sin escuchas.',
    },
    icon: 'BatteryCharging',
    featureIds: ['monitorCPU', 'monitorMemory', 'monitorPower', 'monitorDisk', 'keepAwake', 'brightness', 'extraBrightness', 'mixer', 'soundOutputSwitcher'],
  },
  {
    id: 'developer',
    name: { en: 'Developer Stack', pt: 'Pacote Desenvolvedor', es: 'Paquete Desarrollador' },
    description: {
      en: 'Port Manager, Kill Process, Winget, AI Agents Island, OCR and URL cleaner.',
      pt: 'Port Manager, Encerrar Processo, Winget, Ilha de Agentes IA, OCR e Limpar URL.',
      es: 'Puertos, Finalizar Proceso, Winget, Isla Agentes IA, OCR y URL.',
    },
    icon: 'Terminal',
    featureIds: ['portManager', 'killProcess', 'homebrew', 'appUpdates', 'cleaner', 'uninstaller', 'commandBar', 'urlCleaner', 'screenOCR', 'colorPicker', 'screenshot', 'screenRecorder', 'notch', 'notchAgents', 'monitorCPU', 'monitorMemory', 'monitorNetwork', 'monitorDisk', 'quickToggles'],
  },
];

export const INITIAL_SETTINGS: AppSettings = {
  theme: 'dark',
  locale: 'en',
  activeTab: 'system',
  activeSubview: 'home',
  activeSettingsSection: 'features',
  installedFeatures: Object.fromEntries(FEATURES_CATALOG.map((item) => [item.id, item.defaultInstalled])),
  toggles: {
    switcher: true,
    switcherLargeIcons: true,
    taskbarPreview: true,
    taskbarClickMinimize: true,
    windowMaximizer: true,
    windowEdgeSnap: true,
    autoQuitOnClose: false,
    scrollInverter: false,
    smoothScroll: true,
    linearScroll: false,
    focusFollowsMouse: false,
    mouseAccelDisabled: false,
    clipboardHistory: true,
    explorerCutPaste: true,
    explorerBatchRename: true,
    urlAutoClean: true,
    audioPriority: true,
    micMuteShortcut: true,
    musicBlock: false,
    keepAwakeDisplay: true,
    extraBrightness: true,
    bluetoothSleep: true,
    dynamicIslandEnabled: true,
    dynamicIslandLyrics: true,
    dynamicIslandEqualizer: true,
    dynamicIslandAgents: true,
    dynamicIslandMascot: true,
    separateMenuMetrics: false,
    launchAtStartup: true,
  },
  keepAwakeDuration: 'indefinite',
  brightnessLevel: 82,
  nightWarmth: 18,
  softwareDimming: 0,
  fanPreset: 'balanced',
  fanRpm: 2450,
  wallpaperCategory: 'studio',
  selectedWallpaperId: 'obsidian-ring',
  shortcuts: {
    commandBar: 'Ctrl+K',
    clipboard: 'Ctrl+Shift+V',
    quickPanel: 'Alt+Space',
    appSwitcher: 'Alt+Tab',
    ocr: 'Ctrl+Shift+O',
    screenshot: 'Ctrl+Shift+S',
    micMute: 'Ctrl+Shift+M',
  },
};

export const INITIAL_MIXER_CHANNELS: MixerAppChannel[] = [
  { id: 'discord', name: 'Discord.exe', outputDevice: 'Default', volume: 72, muted: false, color: '#5865f2', active: true },
  { id: 'spotify', name: 'Spotify.exe', outputDevice: 'Default', volume: 145, muted: false, color: '#1db954', active: true },
  { id: 'msedge', name: 'msedge.exe', outputDevice: 'Headphones (Sony WH)', volume: 100, muted: false, color: '#0a84ff', active: true },
  { id: 'vscode', name: 'Code.exe', outputDevice: 'Default', volume: 65, muted: false, color: '#38bdf8', active: false },
];

export const INITIAL_CLIPBOARD: ClipboardItem[] = [
  { id: 'c1', text: 'git push -u origin dev.win', sourceApp: 'WindowsTerminal.exe', timestamp: 'Just now', pinned: true },
  { id: 'c2', text: 'https://github.com/vorssaint/vorssaint-utils/releases?utm_source=digest&fbclid=123', sourceApp: 'msedge.exe', timestamp: '2m ago', pinned: false },
  { id: 'c3', text: 'SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED)', sourceApp: 'Code.exe', timestamp: '9m ago', pinned: false },
];

export const INITIAL_SNIPPETS: TextSnippet[] = [
  { id: 's1', trigger: ';sig', expansion: 'Best regards,\nVorssaint Windows Team', category: 'General' },
  { id: 's2', trigger: ';ghr', expansion: 'https://github.com/alebypegasus/vorssaint-utils-intel/releases', category: 'Dev' },
  { id: 's3', trigger: ';winget', expansion: 'winget upgrade --all --accept-source-agreements', category: 'CLI' },
];

export const INITIAL_SHELF_ITEMS: ShelfItem[] = [
  { id: 'sh1', name: 'Vorssaint-3.7.8.dmg', kind: 'file', sizeLabel: '18.4 MB', addedAt: '04:42' },
  { id: 'sh2', name: 'features-hub-layout.png', kind: 'image', sizeLabel: '642 KB', addedAt: '04:50' },
  { id: 'sh3', name: 'windows-port-spec.md', kind: 'snippet', sizeLabel: '4.2 KB', addedAt: '04:54' },
];

export const INITIAL_NOTES: ScratchpadNote[] = [
  { id: 'n1', title: 'Release Checklist', content: '# Vorssaint 3.7.8\n- Sync upstream Universal 2 on `main`\n- Ship Windows native Tauri build on `dev.win`\n- Verify `cargo check` & `npm run build`', updatedAt: 'Today' },
  { id: 'n2', title: 'Scratchpad', content: 'Quick commands:\n- `winget upgrade`\n- `netstat -ano`', updatedAt: 'Today' },
];

export const INITIAL_AGENTS: DynamicIslandAgent[] = [
  { id: 'claude', name: 'Claude Code', model: 'Claude Sonnet', state: 'active', tokensUsed: 42810, sessionCostUsd: 0.34, taskSummary: 'Refactoring Win32 Audio Endpoint mixer' },
  { id: 'codex', name: 'Codex CLI', model: 'o4-mini', state: 'idle', tokensUsed: 18420, sessionCostUsd: 0.08, taskSummary: 'Completed Cargo workspace verification' },
  { id: 'copilot', name: 'Copilot Agent', model: 'GPT-5', state: 'active', tokensUsed: 11290, sessionCostUsd: 0.11, taskSummary: 'Generating winget manifest checks' },
];

export const WALLPAPER_PRESETS = [
  { id: 'obsidian-ring', title: 'Obsidian Eclipse', category: 'studio', gradient: 'radial-gradient(circle at 25% 20%, #1d2b3f 0%, #0d1017 65%, #07080b 100%)' },
  { id: 'cobalt-horizon', title: 'Cobalt Horizon', category: 'studio', gradient: 'linear-gradient(135deg, #0b1c36 0%, #102a4e 48%, #09111d 100%)' },
  { id: 'nordic-slate', title: 'Nordic Slate', category: 'architecture', gradient: 'linear-gradient(160deg, #1b222c 0%, #27303c 50%, #131820 100%)' },
  { id: 'emerald-ridge', title: 'Emerald Ridge', category: 'landscape', gradient: 'linear-gradient(145deg, #0d2621 0%, #163b33 52%, #081614 100%)' },
  { id: 'warm-amber', title: 'Copper Dusk', category: 'dynamic', gradient: 'linear-gradient(140deg, #2d1c12 0%, #3d2415 45%, #120d0b 100%)' },
  { id: 'silver-daylight', title: 'Frost Mist', category: 'studio', gradient: 'linear-gradient(145deg, #dde4ee 0%, #eef2f8 55%, #cfd7e3 100%)' },
];
