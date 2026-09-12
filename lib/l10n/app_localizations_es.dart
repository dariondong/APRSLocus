// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get confirm => 'Confirmar';

  @override
  String get back => 'Atrás';

  @override
  String get next => 'Siguiente';

  @override
  String get finish => 'Finalizar y conectar';

  @override
  String get previous => 'Anterior';

  @override
  String get search => 'Buscar';

  @override
  String get settings => 'Ajustes';

  @override
  String get greetMorning => 'Buenos días, ';

  @override
  String get greetNoon => 'Buen mediodía, ';

  @override
  String get greetAfternoon => 'Buenas tardes, ';

  @override
  String get greetEvening => 'Buenas noches, ';

  @override
  String get greetNight => 'Hola, ';

  @override
  String get about => 'Acerca de';

  @override
  String get logout => 'Salir';

  @override
  String get retry => 'Reintentar';

  @override
  String get all => 'Todo';

  @override
  String get online => 'En línea';

  @override
  String get offline => 'Sin conexión';

  @override
  String get moving => 'En movimiento';

  @override
  String get emergency => 'Emergencia';

  @override
  String get fixed => 'Fijo';

  @override
  String get infrastructure => 'Digipeater';

  @override
  String get weather => 'Meteorología';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => 'Móvil';

  @override
  String get favorite => 'Favorito';

  @override
  String get grid => 'Cuadrícula';

  @override
  String get callsign => 'Indicativo';

  @override
  String get speed => 'Velocidad';

  @override
  String get altitude => 'Altitud';

  @override
  String get course => 'Rumbo';

  @override
  String get distance => 'Distancia';

  @override
  String get bearing => 'Azimut';

  @override
  String get lastSeen => 'Última señal';

  @override
  String get latitude => 'Latitud';

  @override
  String get longitude => 'Longitud';

  @override
  String get station => 'Estación';

  @override
  String get stations => 'Estaciones';

  @override
  String get messages => 'Mensajes';

  @override
  String get packets => 'Paquetes';

  @override
  String get map => 'Mapa';

  @override
  String get home => 'Inicio';

  @override
  String get connection => 'Conexión';

  @override
  String get connected => 'Conectado';

  @override
  String get disconnected => 'Sin conexión';

  @override
  String get connecting => 'Conectando';

  @override
  String get reconnect => 'Reconectar';

  @override
  String get server => 'Servidor';

  @override
  String get port => 'Puerto';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => 'Baliza de posición';

  @override
  String get beaconInterval => 'Intervalo de baliza (s)';

  @override
  String get nextBeacon => 'Próxima baliza';

  @override
  String get beaconsSent => 'Balizas enviadas';

  @override
  String get symCatVehicles => 'Vehículos / Tráfico';

  @override
  String get symCatBuildings => 'Edificios / Servicios';

  @override
  String get symCatNature => 'Meteorología / Naturaleza';

  @override
  String get symCatAirWater => 'Aire / Agua';

  @override
  String get symCatComms => 'Comunicaciones / Otros';

  @override
  String get homeBadgeLabel => 'Insignia en inicio';

  @override
  String get homeBadgePickTitle => 'Elegir insignia para el inicio';

  @override
  String get homeBadgePickDesc =>
      'Elige una de tus insignias para mostrarla en el inicio';

  @override
  String get simLocationHint => 'Usar una ubicación simulada (sin GPS)';

  @override
  String get speedTierRules => 'Niveles de velocidad';

  @override
  String get restoreDefaults => 'Restaurar valores predeterminados';

  @override
  String get speedTierDesc =>
      'Cuanto más rápido te mueves, más a menudo se reporta; cada nivel puede tener su propio intervalo e icono (vacío = mi símbolo).';

  @override
  String get speedTierShortIntervalWarn =>
      'Intervalos inferiores a 60 s aumentan notablemente la carga del servidor; se recomiendan 60 s o más.';

  @override
  String get addSpeedTier => 'Añadir nivel de velocidad';

  @override
  String get maxSpeedTiers => 'Máximo 5 niveles de velocidad';

  @override
  String get iconDefaultMySymbol => 'Icono · Predeterminado (mi símbolo)';

  @override
  String iconNamed(String name) {
    return 'Icono · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return 'Cada $sec s';
  }

  @override
  String get tierIdleTitle => 'Editar · Nivel reposo/baja velocidad';

  @override
  String get tierSpeedTitle => 'Editar · Nivel de velocidad';

  @override
  String get minSpeedKmh => 'Velocidad mínima (km/h)';

  @override
  String get intervalSeconds => 'Intervalo de reporte (s)';

  @override
  String get idleTierDesc =>
      'Las velocidades por debajo del primer nivel móvil se reportan con este nivel';

  @override
  String get intervalLabel => 'Intervalo';

  @override
  String get unitSeconds => 's';

  @override
  String get pickBeaconIconDesc =>
      'Elige un icono de baliza · «Predeterminado» mantiene mi símbolo';

  @override
  String get defaultLabel => 'Predeterminado';

  @override
  String get deleteThisTier => 'Eliminar este nivel';

  @override
  String get idleTierNotDeletable => 'El nivel de reposo no se puede eliminar';

  @override
  String get errMinSpeedInt => 'La velocidad mínima debe ser un entero ≥ 1';

  @override
  String get errIntervalInt =>
      'El intervalo debe ser un entero de al menos 5 s';

  @override
  String get errTierDuplicate =>
      'Ese nivel ya existe; los umbrales deben ser distintos';

  @override
  String get wsUrlOptional => 'URL de WebSocket (opcional)';

  @override
  String get countryUnrestricted =>
      'Sin país seleccionado · sin restricción (todas las estaciones)';

  @override
  String get weatherWidget => 'Widget del tiempo';

  @override
  String get groupChatLabel => 'Chats grupales';

  @override
  String nItems(String n) {
    return '$n';
  }

  @override
  String nMessages(String n) {
    return '$n';
  }

  @override
  String confirmDeleteMessages(String n) {
    return '¿Eliminar los $n mensajes de chat? Esta acción no se puede deshacer.';
  }

  @override
  String get weatherSimFollowLive => 'Seguir en vivo';

  @override
  String get wxClear => 'Despejado';

  @override
  String get wxCloudy => 'Nublado';

  @override
  String get wxOvercast => 'Cubierto';

  @override
  String get wxLightRain => 'Lluvia ligera';

  @override
  String get wxModerateRain => 'Lluvia moderada';

  @override
  String get wxHeavyRain => 'Lluvia fuerte';

  @override
  String get wxStormRain => 'Lluvia torrencial';

  @override
  String get wxThunder => 'Tormenta eléctrica';

  @override
  String get wxSnow => 'Nieve';

  @override
  String get wxFog => 'Niebla';

  @override
  String get weatherSimTitle =>
      'Simulación del tiempo (vista previa de fondo/efectos/consejos)';

  @override
  String get weatherSimDesc =>
      'Tras elegir, toca la píldora del tiempo en la barra superior para previsualizar; «Seguir en vivo» restaura el tiempo real';

  @override
  String get restartWizardConfirm =>
      'Se abrirá de nuevo el asistente inicial para configurar indicativo, región de recepción, etc.\nTus ajustes actuales se conservan; podrás seguir usando la app al terminar.';

  @override
  String get restartWizardButton => 'Ejecutar de nuevo';

  @override
  String get pasteAprsPacketHint =>
      'Pega un paquete APRS sin procesar, p. ej.\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Estación de prueba';

  @override
  String beaconsSentCount(String n) {
    return '$n';
  }

  @override
  String get myBadgesAndAchievements => 'Mis insignias y logros';

  @override
  String get quitApp => 'Salir de la app';

  @override
  String get quitAppDesc =>
      'Al salir, APRSlocus detiene el reporte de ubicación y la recepción en segundo plano, y finaliza el proceso.';

  @override
  String get symCar => 'Coche';

  @override
  String get openInBrowser => 'Abrir en el navegador';

  @override
  String get badgeWall => 'Muro de insignias';

  @override
  String get achievementWall => 'Muro de logros';

  @override
  String get mapTypeCartoPositron => 'Carto Positron (vector claro)';

  @override
  String get mapTypeCarto => 'Carto claro';

  @override
  String get mapTypeCartoDark => 'Carto oscuro';

  @override
  String get mapTypeCartoVoyager => 'Carto Voyager';

  @override
  String get mapTypeOsm => 'OSM estándar';

  @override
  String get mapTypeOsmHot => 'OSM humanitario';

  @override
  String get mapTypeOpenTopo => 'OpenTopo terreno';

  @override
  String get mapTypeEsriStreet => 'Esri calles';

  @override
  String get mapTypeEsriSat => 'Esri imágenes';

  @override
  String get simulatedKeepAlive => 'Ubicación simulada · keep-alive';

  @override
  String get symCatEmergency => 'Emergencias';

  @override
  String get symSmallAircraft => 'Avioneta';

  @override
  String myPositionSet(String grid) {
    return 'Mi posición establecida, cuadrícula $grid';
  }

  @override
  String get tierIdleShort => 'Reposo/baja velocidad';

  @override
  String get symHouse => 'Casa';

  @override
  String get symPerson => 'Persona';

  @override
  String get symTruck => 'Camión';

  @override
  String get symBicycle => 'Bicicleta';

  @override
  String get symRv => 'Autocaravana';

  @override
  String get symWxStation => 'Estación meteorológica';

  @override
  String get symPolice => 'Policía';

  @override
  String get symMotorcycle => 'Moto';

  @override
  String get symSemi => 'Semirremolque';

  @override
  String get symVan => 'Furgoneta';

  @override
  String get symJeep => 'Jeep';

  @override
  String get symBus => 'Autobús';

  @override
  String get symTruckStop => 'Área de camiones';

  @override
  String get symTrain => 'Tren';

  @override
  String get symFireTruck => 'Camión de bomberos';

  @override
  String get symPoliceCar => 'Coche de policía';

  @override
  String get symSnowmobile => 'Moto de nieve';

  @override
  String get symYagi => 'Yagi';

  @override
  String get symHospital => 'Hospital';

  @override
  String get symAmbulance => 'Ambulancia';

  @override
  String get symFireStation => 'Parque de bomberos';

  @override
  String get symSchool => 'Escuela';

  @override
  String get symMotel => 'Motel';

  @override
  String get symHotel => 'Hotel';

  @override
  String get symLaptop => 'Portátil';

  @override
  String get symPostOffice => 'Oficina de correos';

  @override
  String get symWeather => 'Meteorología';

  @override
  String get symWater => 'Punto de agua';

  @override
  String get symHurricane => 'Huracán';

  @override
  String get symHorse => 'A caballo';

  @override
  String get symDog => 'Perro';

  @override
  String get symCamping => 'Acampada';

  @override
  String get symShelter => 'Refugio';

  @override
  String get symRedCross => 'Cruz Roja';

  @override
  String get symFireAlarm => 'Alarma de incendios';

  @override
  String get symEmergCenter => 'Centro de emergencias';

  @override
  String get symCmdCenter => 'Centro de mando';

  @override
  String get symHandicap => 'Discapacidad';

  @override
  String get symBigAircraft => 'Avión grande';

  @override
  String get symGlider => 'Planeador';

  @override
  String get symBalloon => 'Globo';

  @override
  String get symShip => 'Barco';

  @override
  String get symSailboat => 'Velero';

  @override
  String get symMobileSat => 'Satélite móvil';

  @override
  String get symSatAntenna => 'Antena de satélite';

  @override
  String get symDigi => 'Repetidor digital';

  @override
  String get symDigiTower => 'Torre repetidora';

  @override
  String get symMicE => 'Repetidor Mic-E';

  @override
  String get symNode => 'Nodo';

  @override
  String get symDxCluster => 'Clúster DX';

  @override
  String get symHfGateway => 'Pasarela HF';

  @override
  String get symFileServer => 'Servidor de archivos';

  @override
  String get symTelephone => 'Teléfono';

  @override
  String get symGrid => 'Cuadrícula';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'Estación FMO';

  @override
  String get filter => 'Filtro de rango';

  @override
  String get filterRadius => 'Radio (km)';

  @override
  String get maxStations => 'Máx. estaciones';

  @override
  String get receiveFilter => 'Filtro por indicativo';

  @override
  String get receiveCountries => 'Países';

  @override
  String get receiveOthers => 'Otras estaciones';

  @override
  String get darkMode => 'Modo oscuro';

  @override
  String get themeColor => 'Color del tema';

  @override
  String get language => 'Idioma';

  @override
  String get languageSystem => 'Seguir al sistema';

  @override
  String get languageZh => '中文';

  @override
  String get languageEn => 'English';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageJa => '日本語';

  @override
  String get languageId => 'Bahasa Indonesia';

  @override
  String get languageEs => 'Español';

  @override
  String get displaySettings => 'Ajustes de pantalla';

  @override
  String get uiScale => 'Escala de la interfaz';

  @override
  String get reloadUi => 'Recargar interfaz';

  @override
  String get reloadDone => 'Recargado';

  @override
  String get mapType => 'Tipo de mapa';

  @override
  String get unit => 'Unidad';

  @override
  String get coordDatum => 'Datum';

  @override
  String get stationSettings => 'Ajustes de estación';

  @override
  String get connectionSettings => 'Ajustes de conexión';

  @override
  String get chatSettings => 'Ajustes del chat';

  @override
  String get dataSettings => 'Ajustes de datos';

  @override
  String get advancedSettings => 'Ajustes avanzados';

  @override
  String get sponsors => 'Patrocinadores y agradecimientos';

  @override
  String get sponsorsThanks => 'Gracias a todos los que apoyan';

  @override
  String get send => 'Enviar';

  @override
  String get receive => 'Recibir';

  @override
  String get clear => 'Borrar';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get version => 'Versión';

  @override
  String get location => 'Ubicación';

  @override
  String get gpsStatus => 'Estado del GPS';

  @override
  String get myLocation => 'Mi ubicación';

  @override
  String get track => 'Rastro';

  @override
  String get forwardingPath => 'Ruta';

  @override
  String get relatedStations => 'Estaciones relacionadas';

  @override
  String get openInMap => 'Ver en el mapa';

  @override
  String get navigate => 'Navegar';

  @override
  String get messageSent => 'Mensaje enviado';

  @override
  String get enterMessage => 'Escribe un mensaje';

  @override
  String get noData => 'Sin datos';

  @override
  String get searchHint =>
      'Buscar indicativo / tipo / cuadrícula / comentario…';

  @override
  String get notFound => 'No se encontraron estaciones';

  @override
  String get totalStations => 'Total';

  @override
  String get sortBy => 'Ordenar';

  @override
  String get sortCall => 'Indicativo';

  @override
  String get sortRecent => 'Reciente';

  @override
  String get sortDistance => 'Distancia';

  @override
  String get sortStatus => 'Estado';

  @override
  String get typeFilter => 'Tipo';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => '¿Eliminar este elemento?';

  @override
  String get confirmRestartOobe =>
      'Se abrirá de nuevo el asistente inicial para configurar indicativo, región de recepción, etc.\nTus ajustes actuales se conservarán.';

  @override
  String get restartWizard => 'Ejecutar de nuevo el asistente';

  @override
  String get restartWizardTitle => '¿Ejecutar de nuevo el asistente?';

  @override
  String get oobeFilterTitle => 'Elegir región de recepción';

  @override
  String get oobeFilterDesc =>
      'De forma predeterminada solo se reciben indicativos chinos. Añade otros países según sea necesario.';

  @override
  String get oobeWelcomeTitle => 'Te damos la bienvenida a APRSlocus';

  @override
  String get oobeWelcomeRealMap => 'Mapa en vivo';

  @override
  String get oobeWelcomeGps => 'Baliza de posición GPS';

  @override
  String get oobeWelcomeMsg => 'Mensajes APRS';

  @override
  String get oobeWelcomeIs => 'Conexión APRS-IS';

  @override
  String get oobeCallTitle => 'Tu indicativo';

  @override
  String get oobeSymbolTitle => 'Elegir símbolo de estación';

  @override
  String get oobeServerTitle => 'Conectar al servidor APRS-IS';

  @override
  String get weatherData => 'Datos meteorológicos';

  @override
  String get fmoInfo => 'Información FMO';

  @override
  String get aprslocusInfo => 'Información de APRSlocus';

  @override
  String get locationInfo => 'Ubicación';

  @override
  String get recentPackets => 'Paquetes recientes';

  @override
  String get quickActions => 'Acciones rápidas';

  @override
  String get copyCoords => 'Copiar coordenadas';

  @override
  String get copyGrid => 'Copiar cuadrícula';

  @override
  String get sender => 'Remitente';

  @override
  String get time => 'Hora';

  @override
  String get message => 'Mensaje';

  @override
  String get groupChat => 'Chat grupal';

  @override
  String get newGroup => 'Nuevo grupo';

  @override
  String get sendTo => 'Enviar a';

  @override
  String get filterRule => 'Regla de filtro';

  @override
  String get saveAndApply => 'Guardar y aplicar filtro';

  @override
  String get useMyLocation => 'Usar mi ubicación como centro del filtro';

  @override
  String get noFixYet =>
      'Aún no hay posición; la ubicación actual no está disponible';

  @override
  String get invalidCoords => 'Introduce latitud, longitud y radio válidos';

  @override
  String get filterSaved => 'Filtro guardado y aplicado';

  @override
  String get stationsShown => 'Estaciones';

  @override
  String get settingsDesc => 'Configura estación, ubicación y conexión';

  @override
  String get radioCat => 'Estación';

  @override
  String get radioCatDesc => 'Indicativo · SSID · Símbolo';

  @override
  String get beaconCat => 'Balizamiento';

  @override
  String get beaconCatDesc => 'GPS · Baliza · Posición manual';

  @override
  String get connectionCat => 'Conexión';

  @override
  String get connectionCatDesc => 'Servidor · Filtro de rango';

  @override
  String get displayCat => 'Pantalla';

  @override
  String get displayCatDesc => 'Coordenadas · Tema';

  @override
  String get chatCat => 'Chat';

  @override
  String get chatCatDesc => 'Historial · Contactos';

  @override
  String get dataCat => 'Datos';

  @override
  String get dataCatDesc => 'Borrar datos locales';

  @override
  String get advancedCat => 'Avanzado';

  @override
  String get advancedCatDesc => 'Laboratorio · Desarrollador';

  @override
  String get updateCat => 'Actualización';

  @override
  String get updateCatDesc => 'Buscar nuevas versiones';

  @override
  String get checkUpdate => 'Buscar actualización';

  @override
  String get myStationSettings => 'Mi estación';

  @override
  String get myStationSettingsDesc => 'Indicativo · SSID · Símbolo · Baliza';

  @override
  String get oobeWelcomeDesc => 'Empieza a configurar tu estación APRS';

  @override
  String get oobeCallDesc => 'Introduce tu indicativo';

  @override
  String get oobeSymbolDesc =>
      'El símbolo representa el tipo de estación y se envía con las balizas de posición';

  @override
  String get oobeServerDesc =>
      'Conéctate para recibir datos de estaciones APRS de todo el mundo. La configuración predeterminada funciona tal cual.';

  @override
  String get wizard => 'Asistente de configuración';

  @override
  String get setStep => 'Paso';

  @override
  String get chooseSymbol => 'Elegir símbolo de estación';

  @override
  String get settingsSubtitle =>
      'Coordenadas del mapa y preferencias de pantalla';

  @override
  String get stationSettingsSubtitle => 'Indicativo, símbolo y baliza';

  @override
  String get connectionSettingsSubtitle =>
      'Servidor APRS-IS y rango de recepción';

  @override
  String get chatSettingsSubtitle => 'Historial de mensajes y contactos';

  @override
  String get dataSettingsSubtitle => 'Gestión de datos locales';

  @override
  String get advancedSettingsSubtitle =>
      'Laboratorio y herramientas de desarrollo';

  @override
  String get stationListTitle => 'Estaciones';

  @override
  String get filters => 'Filtros';

  @override
  String get clearAll => 'Borrar todo';

  @override
  String get statusFilter => 'Estado';

  @override
  String get typeGroup => 'Tipo';

  @override
  String get appFilter => 'App';

  @override
  String get mapMenu => 'Menú del mapa';

  @override
  String get mapTypeTitle => 'Tipo de mapa';

  @override
  String get selectMapType => 'Seleccionar tipo de mapa';

  @override
  String get showTrails => 'Mostrar rastros';

  @override
  String get showStations => 'Mostrar estaciones';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutSubtitle => 'Seguimiento y mapas APRS';

  @override
  String get author => 'Autor';

  @override
  String get codeContributions => 'Contribuciones de código';

  @override
  String get codeContributionI18n =>
      'Internacionalización / interfaz en inglés';

  @override
  String get codeContributionZhTw => 'Interfaz en chino tradicional';

  @override
  String get licenseSection => 'Licencia';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      'Este software se publica bajo la licencia GNU GPL v3. Puedes ejecutarlo, estudiarlo, modificarlo y redistribuirlo conforme a los términos de la licencia; las versiones modificadas y redistribuidas deben cumplir las obligaciones aplicables de la GPL v3. Este software se ofrece sin garantía alguna.';

  @override
  String get licenseText => 'Ver licencia';

  @override
  String get oobeAgreeTitle => 'Acuerdo de usuario y licencia';

  @override
  String get oobeAgreeBody =>
      '¡Te damos la bienvenida a APRSlocus! Antes de usar la app, lee y acepta los términos siguientes. Ten en cuenta que los datos APRS son públicos: una vez enviados, pueden ser recibidos, almacenados y reenviados por la red APRS mundial.';

  @override
  String get oobeAgreeCheck =>
      'He leído y acepto el Acuerdo de usuario y la licencia GPL-3.0';

  @override
  String get oobeAgreeNeed => 'Lee y marca primero el Acuerdo de usuario';

  @override
  String get oobeDeclineExit => 'Rechazar y salir';

  @override
  String get userAgreement => 'Acuerdo de usuario';

  @override
  String get beaconWarnTitle => 'Intervalo de baliza demasiado corto';

  @override
  String get beaconWarnBody =>
      'APRS-IS recomienda un intervalo de baliza mínimo de 60 segundos para estaciones móviles. Enviar más rápido puede considerarse un abuso y provocar la desconexión. ¿Mantener este intervalo?';

  @override
  String get beaconWarnKeep => 'Mantener igualmente';

  @override
  String get beaconWarnFix => 'Poner 60 s';

  @override
  String get features => 'Funciones';

  @override
  String get openSource => 'Agradecimientos de código abierto';

  @override
  String get feedback => 'Comentarios';

  @override
  String get officialWebsite => 'Sitio web oficial';

  @override
  String get qqGroup => 'Grupo de QQ';

  @override
  String get projectRepo => 'Repositorio';

  @override
  String get testMembers => 'Colaboradores de prueba';

  @override
  String get aiSupport => 'Apoyo de cómputo con IA';

  @override
  String get copyAppInfo => 'Copiar información de la app';

  @override
  String get appInfoCopied => 'Información de la app copiada';

  @override
  String get shareApp => 'Compartir APRSlocus';

  @override
  String get shareToSystem => 'Compartir en el sistema';

  @override
  String get shareToSystemDesc => 'WeChat, QQ, SMS, etc.';

  @override
  String get copyShareText => 'Copiar texto para compartir';

  @override
  String get openDownload => 'Abrir página de descarga';

  @override
  String get shareTextCopied =>
      'Texto copiado; pégalo para enviarlo a tus amigos';

  @override
  String get shareText =>
      'APRSlocus — Seguimiento y mapas APRS para radioaficionados 📡\nSeguimiento de estaciones en tiempo real, mensajería y balizas. Disponible en Android y Windows.\nWeb: https://aprslocus.theez.top/\nDescarga: https://github.com/dariondong/APRSLocus/releases';

  @override
  String get enterCallsign => 'Introduce tu indicativo';

  @override
  String get enterValidCall => 'Introduce un indicativo válido';

  @override
  String get stationSettings2 => 'Ajustes de estación';

  @override
  String get beaconSettings => 'Balizamiento';

  @override
  String get displaySettings2 => 'Ajustes de pantalla';

  @override
  String get chatSettings2 => 'Ajustes del chat';

  @override
  String get dataSettings2 => 'Ajustes de datos';

  @override
  String get advancedSettings2 => 'Ajustes avanzados';

  @override
  String get connectionSettings2 => 'Ajustes de conexión';

  @override
  String get myCallsign => 'Mi indicativo';

  @override
  String get beaconEnabled => 'Activar baliza de posición';

  @override
  String get smartBeacon => 'SmartBeacon (por velocidad)';

  @override
  String get packetConsole => 'Consola de paquetes';

  @override
  String get rawMode => 'Modo sin procesar';

  @override
  String get parsedMode => 'Modo analizado';

  @override
  String get position => 'Posición';

  @override
  String get statusType => 'Estado';

  @override
  String get objectType => 'Objeto';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return 'RX $rx · TX $tx · $ppm/min';
  }

  @override
  String get searchPacket => 'Buscar indicativo, destino o bruto…';

  @override
  String get noMatchingPackets => 'No hay paquetes coincidentes';

  @override
  String get inject => 'Inyectar';

  @override
  String get manualInject => 'Inyectar paquete APRS sin procesar';

  @override
  String get injected => 'Paquete inyectado';

  @override
  String get clearedPackets => 'Paquetes borrados';

  @override
  String get clearPackets => 'Borrar paquetes';

  @override
  String noPositionInfo(Object call) {
    return '$call no tiene información de posición (el paquete no incluye posición)';
  }

  @override
  String get copiedPacket => 'Paquete copiado';

  @override
  String get mapPickMode => 'Modo de selección en el mapa';

  @override
  String get mapPickDesc => 'Toca el mapa para fijar tu posición';

  @override
  String foundStations(Object count, Object q) {
    return '$count estaciones coinciden con «$q»';
  }

  @override
  String get tapMapHint =>
      'Toca el mapa para ver estaciones · pellizca para ampliar';

  @override
  String myLocationPanel(Object call) {
    return 'Mi ubicación · $call';
  }

  @override
  String get speedLabel => 'Velocidad';

  @override
  String get courseLabel => 'Rumbo';

  @override
  String get telemetryTitle => 'Cambios de velocidad / altitud';

  @override
  String get range10m => '10 min';

  @override
  String get range30m => '30 min';

  @override
  String get range1h => '1 h';

  @override
  String get range3h => '3 h';

  @override
  String get rangeAll => 'Todo';

  @override
  String get beaconIntervalLabel => 'Intervalo';

  @override
  String get beaconsSentLabel => 'Enviadas';

  @override
  String get nextBeaconLabel => 'Próxima';

  @override
  String positionBeacon(Object grid) {
    return 'Baliza de posición · Cuadrícula $grid';
  }

  @override
  String get manualBeacon => 'Balizar ahora';

  @override
  String get mapPickNow => 'Elegir en el mapa';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return 'Posición fijada · $lat, $lng · Cuadrícula $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count en línea';
  }

  @override
  String movingCount(Object count) {
    return '$count en movimiento';
  }

  @override
  String stationCount(Object count) {
    return '$count estaciones';
  }

  @override
  String get locateMe => 'Localizar';

  @override
  String get layerFilter => 'Capas';

  @override
  String get showAll => 'Mostrar todo';

  @override
  String get otherType => 'Otros';

  @override
  String zoomLevel(Object z) {
    return 'Zoom $z';
  }

  @override
  String get datumGcj => 'GCJ-02 (AMap)';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '$d km';
  }

  @override
  String get noStationInView =>
      'No hay estaciones aquí · toca para mostrar todas';

  @override
  String get noStationHelp => 'No hay estaciones aquí · toca para ver la ayuda';

  @override
  String get mapHelpTitle => 'Ayuda del mapa';

  @override
  String get mapHelpIntro =>
      'No hay estaciones en la vista actual. Posibles motivos: sin conexión a APRS-IS, rango de recepción pequeño o ninguna estación activa cerca.';

  @override
  String get mapHelpMove =>
      'Mover / ampliar: arrastra para desplazar, pellizca o usa la rueda para ampliar';

  @override
  String get mapHelpStation =>
      'Estaciones: toca un marcador para seleccionarlo y centrarlo, doble toque para ver detalles';

  @override
  String get mapHelpLayer =>
      'Capas y estilo: los botones de arriba a la derecha filtran tipos de estación y cambian el mapa base';

  @override
  String get mapHelpLocate =>
      'Localizar: toca «Localizarme» (abajo a la derecha) para volver a tu posición';

  @override
  String get mapHelpSearch =>
      'Buscar: escribe un indicativo en el cuadro de búsqueda superior para ir a él';

  @override
  String get allChangelog => 'Todos los cambios';

  @override
  String get tapToView => 'Toca para ver';

  @override
  String get beaconNow => 'Balizar ahora';

  @override
  String get meLabel => 'Yo';

  @override
  String get mapZoomIn => 'Ampliar';

  @override
  String get mapZoomOut => 'Reducir';

  @override
  String get mapHome => 'Recentrar';

  @override
  String get mapLocate => 'Localizar';

  @override
  String get mapLayers => 'Capas';

  @override
  String get featureLiveMap => 'AMap';

  @override
  String get featureLiveMapDesc =>
      'Coordenadas GCJ-02 con desplazamiento y zoom fluidos';

  @override
  String get featureGps => 'Posicionamiento GPS';

  @override
  String get featureGpsDesc =>
      'Ubicación nativa de Android, sin servicios de Google';

  @override
  String get featureBeacon => 'Balizamiento';

  @override
  String get featureBeaconDesc =>
      'Contenido, frecuencia y símbolo personalizados con formato estándar APRS';

  @override
  String get featureMsg => 'Mensajes';

  @override
  String get featureMsgDesc =>
      'Vistas de flujo y de conversación, con texto Unicode y respuesta automática';

  @override
  String get featureAutoConnect => 'Conexión automática';

  @override
  String get featureAutoConnectDesc =>
      'Se conecta automáticamente a un servidor público y permanece en línea en segundo plano';

  @override
  String get featureLayerFilter => 'Filtro de capas';

  @override
  String get featureLayerFilterDesc =>
      'Filtrar: móvil, fijo, digipeater, meteorología, FMO';

  @override
  String get featureFmo => 'Estaciones FMO';

  @override
  String get featureFmoDesc =>
      'Detecta automáticamente datos FMO y muestra información estructurada';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Marco de interfaz multiplataforma de Google';

  @override
  String get osAmap => 'AMap';

  @override
  String get osAmapDesc => 'Servicio de teselas de mapa';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => 'Red mundial de datos APRS';

  @override
  String get osHam => 'Radioaficionados';

  @override
  String get osHamDesc =>
      'Aportaciones de toda la comunidad APRS de radioaficionados';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => 'Indicativo';

  @override
  String get website => 'Sitio web';

  @override
  String get sponsorAuthor => 'Autor BG7LZQ';

  @override
  String get sponsorAuthorItems =>
      'Desarrolla y mantiene este proyecto en su tiempo libre';

  @override
  String get sponsorGroup => 'STUDENT HAMS';

  @override
  String get sponsorGroupItems => 'Gracias al grupo por su apoyo económico';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => 'Gracias por patrocinar un Mixue 🧋';

  @override
  String get sponsorEvery => 'Todos los que apoyan';

  @override
  String get sponsorEveryItems =>
      'Cada aportación ayuda a que el proyecto siga adelante';

  @override
  String get donateWechat => 'Donación por WeChat';

  @override
  String get donateWechatDesc =>
      'Mantén pulsado para guardar el código QR · toca para ampliarlo';

  @override
  String get donateAlipay => 'Donación por Alipay';

  @override
  String get donateAlipayDesc =>
      'Contacta con el autor para obtener el código QR de donación';

  @override
  String get nonprofitNote =>
      'Este es un proyecto sin ánimo de lucro para aprender e intercambiar\nLas donaciones solo cubren los costes de servidor y desarrollo';

  @override
  String get myStation => 'Mi estación';

  @override
  String get callSsid => 'Indicativo · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc =>
      'El SSID es un sufijo del indicativo que identifica el equipo; p. ej., -9 en BG7ABC-9';

  @override
  String get callComment => 'Comentario de estación';

  @override
  String get callCommentHint =>
      'Comentario que se envía con las balizas de posición';

  @override
  String get callSymbol => 'Símbolo de estación';

  @override
  String get callSymbolDesc =>
      'El símbolo se envía con las balizas de posición';

  @override
  String get autoReply => 'Respuesta automática';

  @override
  String get sendBeacon => 'Enviar baliza';

  @override
  String get mapTypeDesc =>
      '«Mapa 2.0 (vectorial)» se dibuja en el dispositivo: menos datos y zoom nítido; AMap vectorial/satélite usa teselas en línea.';

  @override
  String get msgHistory => 'Historial de mensajes';

  @override
  String get statistics => 'Estadísticas';

  @override
  String get clearData => 'Borrar datos';

  @override
  String get favorites => 'Favoritos / Manuales';

  @override
  String get favoriteStations => 'Estaciones favoritas';

  @override
  String get manualStations => 'Estaciones manuales';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get onlyWgs84 => 'Solo WGS-84';

  @override
  String get contactList => 'Contactos';

  @override
  String get contactDesc => 'Reglas de filtrado de mensajes y contactos';

  @override
  String get dataClearDesc =>
      'Borra mensajes, paquetes, estaciones y otros datos locales';

  @override
  String get advancedDesc => 'Laboratorio y herramientas de desarrollo';

  @override
  String get labDesc =>
      'Las funciones de laboratorio están en pruebas y pueden afectar al uso. La orientación vertical está bloqueada por defecto; actívalo para permitir la horizontal.';

  @override
  String get systemLog => 'Registro del sistema';

  @override
  String get devDesc => 'Herramientas de depuración';

  @override
  String get simData =>
      'Activar datos de demostración (estaciones/paquetes de ejemplo)';

  @override
  String get rxTx => 'RX / TX';

  @override
  String get stationCount2 => 'Número de estaciones';

  @override
  String get appInfo => 'Información de la app';

  @override
  String get clearMessages => 'Borrar todo el historial de chat';

  @override
  String get clearPackets2 => 'Borrar paquetes';

  @override
  String get clearStations => 'Borrar lista de estaciones';

  @override
  String get clearCache => 'Borrar caché';

  @override
  String get resetAll => 'Restablecer toda la configuración';

  @override
  String get resetAllDesc => 'Restablecer valores de fábrica';

  @override
  String get dataPersistence => 'Persistencia de estaciones';

  @override
  String get autoSaveStations =>
      'Guardar automáticamente los datos de estaciones';

  @override
  String get gridFormat => 'Formato de cuadrícula';

  @override
  String get coordsFormat => 'Formato de coordenadas';

  @override
  String get appVersion => 'Versión';

  @override
  String get appVersionDesc => 'Versión actual de la app';

  @override
  String get stationDetail => 'Detalle de estación';

  @override
  String get backToTop => 'Volver arriba';

  @override
  String get installApk => 'Instalar APRSlocus';

  @override
  String get install => 'Instalar';

  @override
  String get cancelInstall => 'Cancelar';

  @override
  String get openFolder => 'Abrir carpeta';

  @override
  String get browse => 'Examinar';

  @override
  String get downloadUpdate => 'Descargar actualización';

  @override
  String get downloadNow => 'Descargar ahora';

  @override
  String get downloading => 'Descargando';

  @override
  String downloadProgress(Object p) {
    return 'Descargando $p%';
  }

  @override
  String get downloadComplete => 'Descarga completada';

  @override
  String get downloadFailed => 'Error de descarga';

  @override
  String get installNow => 'Instalar ahora';

  @override
  String get installComplete => 'Instalación completada';

  @override
  String get openInstallDir => 'Abrir carpeta de instalación';

  @override
  String get deletePackage => 'Eliminar paquete';

  @override
  String deletePackageConfirm(Object file) {
    return '¿Eliminar el paquete $file?';
  }

  @override
  String get deleteAllPackages => 'Eliminar todos los paquetes';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return 'Eliminar todos los paquetes ($count)';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return 'Se eliminarán $count paquetes descargados ($size). ¿Continuar?';
  }

  @override
  String get historyVersions => 'Historial';

  @override
  String get current => 'Actual';

  @override
  String get newVersion => 'Nueva versión';

  @override
  String get latestVersion => 'Ya tienes la última versión';

  @override
  String get currentVersion => 'Versión actual de APRSlocus';

  @override
  String get checking => 'Buscando actualizaciones…';

  @override
  String get checkingGitCode => 'Comprobando el repositorio de GitCode';

  @override
  String get updateFailed => 'Error al buscar actualizaciones';

  @override
  String get noUpdateFound => 'Ya tienes la última versión';

  @override
  String get newVersionFound => 'Nueva versión disponible';

  @override
  String get downloadAgain => 'Volver a descargar el paquete';

  @override
  String get openDownloads => 'Abrir carpeta de descargas';

  @override
  String get releaseNotes => 'Notas de la versión';

  @override
  String currentVsRepo(Object local, Object remote) {
    return 'Instalada v$local · Última en el repositorio v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return 'Tamaño del paquete $os: $size';
  }

  @override
  String get alreadyDownloaded => 'Paquete descargado';

  @override
  String get downloadReady => 'Descargar paquete de instalación';

  @override
  String get appInstallDir => 'Carpeta de instalación';

  @override
  String get runInstaller => 'Ejecutar instalador';

  @override
  String get downloadUpdateTip => 'Descargar la actualización y abrirla';

  @override
  String get openDownloadFolder => 'Abrir carpeta de descargas';

  @override
  String groupBubble(String name) {
    return 'Grupo · $name';
  }

  @override
  String get groupInviteTitle => 'Invitación a chat grupal';

  @override
  String groupInviteFrom(String from) {
    return '$from te ha invitado a un chat grupal';
  }

  @override
  String groupNameValue(String name) {
    return 'Grupo: $name';
  }

  @override
  String groupCallsignValue(String call) {
    return 'Indicativo del grupo: $call';
  }

  @override
  String groupInviteAccepted(String name) {
    return 'Te has unido a $name';
  }

  @override
  String get accept => 'Aceptar';

  @override
  String groupInviteRejected(String name) {
    return 'Has rechazado la invitación a $name';
  }

  @override
  String get reject => 'Rechazar';

  @override
  String get appTagline => 'Seguimiento APRS';

  @override
  String gridValue(String grid) {
    return 'Cuadrícula $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/min';
  }

  @override
  String get demo => 'Demo';

  @override
  String nextBeaconIn(String time) {
    return 'Próxima baliza $time';
  }

  @override
  String beaconCount(int count) {
    return '$count balizas';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return 'Baliza de posición enviada · Cuadrícula $grid · Enviada a APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return 'Baliza de posición enviada · Cuadrícula $grid · Demo';
  }

  @override
  String get getLocation => 'Obtener ubicación';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get connectAprsIs => 'Conectar APRS-IS';

  @override
  String get packetsReceived => 'RX';

  @override
  String get passcodeUnverified => 'Passcode sin verificar';

  @override
  String get passcodeWarning =>
      'Es posible que el passcode de acceso sea incorrecto; los mensajes podrían no funcionar';

  @override
  String get goSettings => 'Ajustes';

  @override
  String get connectingServer => 'Conectando al servidor…';

  @override
  String get notConnectedAprsServer => 'Sin conexión al servidor APRS-IS';

  @override
  String connectingToServer(String server, int port) {
    return 'Conectando a $server:$port…';
  }

  @override
  String get connectNearbyDesc =>
      'Conéctate para recibir posiciones y mensajes de estaciones cercanas';

  @override
  String get connectAction => 'Conectar';

  @override
  String get backgroundRunTip =>
      'Ejecución en segundo plano: para mantener el balizamiento activo, permite que APRSlocus se ejecute en segundo plano, desactiva la optimización de batería y permite el inicio automático.';

  @override
  String get connectedAprsIs => 'Conectado a APRS-IS';

  @override
  String get qqGroupDesc => 'APRSlocus · Comentarios y dudas';

  @override
  String get reselectPoint => 'Elegir de nuevo';

  @override
  String get disableClustering => 'Desactivar agrupación';

  @override
  String get enableClustering => 'Activar agrupación';

  @override
  String get heatmap => 'Mapa de calor de estaciones';

  @override
  String get heatmapHint =>
      'Mostrar un mapa de calor de densidad de estaciones al alejar';

  @override
  String get groupTracking => 'Seguimiento por grupos';

  @override
  String get groupTrackingHint =>
      'Agrupa los indicativos que te interesan y síguelos en un mapa grande (caravana / amigos). Compatible con horizontal.';

  @override
  String get newTrackGroup => 'Nuevo grupo de seguimiento';

  @override
  String get trackGroupNameHint => 'Nombre, p. ej. Ruta de fin de semana';

  @override
  String get editTrackGroup => 'Editar grupo de seguimiento';

  @override
  String get deleteTrackGroup => 'Eliminar grupo de seguimiento';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return '¿Eliminar el grupo de seguimiento «$name»?';
  }

  @override
  String get pickTrackMembers =>
      'Elegir miembros (marca los indicativos que quieras seguir)';

  @override
  String get saveAndTrack => 'Guardar y seguir';

  @override
  String get trackGroupsEmptyHint =>
      'Aún no hay grupos de seguimiento. Toca «Nuevo grupo de seguimiento» para crear uno.';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty =>
      'Los miembros aún no tienen datos de posición (no recibidos o sin baliza).';

  @override
  String get trackActive => 'Activo';

  @override
  String get trackWaitingPos => 'Esperando posición…';

  @override
  String get offlineShort => 'Sin conexión';

  @override
  String get stoppedShort => 'Detenido';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total miembros · $online en línea · $fixed fijos';
  }

  @override
  String get groupChatShort => 'Chat';

  @override
  String groupChatTitle(Object name) {
    return 'Grupo · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return 'Chat con $call';
  }

  @override
  String get chatToGroupHint => 'Envía un mensaje al grupo…';

  @override
  String chatToHint(Object call) {
    return 'Envía un mensaje a $call…';
  }

  @override
  String get noMessagesHint => 'Aún no hay mensajes; ¡saluda!';

  @override
  String trackModeFollow(Object call) {
    return 'Siguiendo a $call';
  }

  @override
  String get trackModeMe => 'Siguiéndome';

  @override
  String get trackModeFitAll => 'Vista completa';

  @override
  String get fitAll => 'Ver todo';

  @override
  String get noStationsYet =>
      'Aún no hay datos de estaciones. Conéctate a APRS-IS para elegir miembros.';

  @override
  String get noPackets => 'Aún no hay paquetes';

  @override
  String secondsAgo(int count) {
    return 'hace ${count}s';
  }

  @override
  String minutesAgo(int count) {
    return 'hace $count min';
  }

  @override
  String hoursAgo(int count) {
    return 'hace $count h';
  }

  @override
  String daysAgo(int count) {
    return 'hace $count d';
  }

  @override
  String copiedCoordsValue(String coords) {
    return 'Coordenadas copiadas: $coords';
  }

  @override
  String copiedGridValue(String grid) {
    return 'Cuadrícula copiada: $grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return 'A $distance km · Azimut $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return 'Meteorología · $data';
  }

  @override
  String get symbolLabel => 'Símbolo';

  @override
  String get digipeaterTapHint =>
      'Toca un digipeater para abrir los detalles de su estación';

  @override
  String get copiedFmoInfo => 'Información FMO copiada';

  @override
  String get copiedAprslocusInfo => 'Información de APRSlocus copiada';

  @override
  String trackPoints(int count) {
    return 'Rastro ($count puntos)';
  }

  @override
  String sendMessageTo(String call) {
    return 'Envía un mensaje a $call…';
  }

  @override
  String get navigationUnavailable =>
      'No se pudo abrir AMap ni otra aplicación de mapas';

  @override
  String stationNoData(String call) {
    return 'Aún no se han recibido datos de $call';
  }

  @override
  String get software => 'Software';

  @override
  String get close => 'Cerrar';

  @override
  String get nameLabel => 'Nombre';

  @override
  String get viewSponsorDetails => 'Ver detalles del autor y patrocinadores →';

  @override
  String get thanks => 'Gracias';

  @override
  String get qqSoftwareName => 'APRSlocus';

  @override
  String get usageNotice =>
      'Solo para aprendizaje e intercambio entre radioaficionados\nCumple la normativa local de radio';

  @override
  String get licenseNotice => 'Licencia GNU GPL v3 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\nAutor: BG7LZQ (Darion)\nWeb: Theez.top';
  }

  @override
  String get eggBg7lzq => 'Oye, ¿qué haces?~';

  @override
  String get eggBg7pgw => '¿En serio?';

  @override
  String get eggBg7lmw => 'Silencio absoluto...';

  @override
  String get eggBg7osl => 'Tienes mucho morro';

  @override
  String get manualCallsignHint => 'Añadir indicativo manualmente';

  @override
  String get noPacketReceived => 'No se han recibido paquetes';

  @override
  String get feedMode => 'Flujo';

  @override
  String get conversationMode => 'Chats';

  @override
  String get messageFeed => 'Flujo de mensajes';

  @override
  String messageTotal(int count) {
    return '$count mensajes';
  }

  @override
  String get noMessages => 'Aún no hay mensajes';

  @override
  String get copiedClipboard => 'Copiado al portapapeles';

  @override
  String get groupShortLabel => 'Grupo';

  @override
  String get conversations => 'Chats';

  @override
  String get noConversations => 'Aún no hay conversaciones';

  @override
  String get groupNotFound => 'Chat grupal no encontrado';

  @override
  String get invite => 'Invitar';

  @override
  String get manage => 'Gestionar';

  @override
  String get noGroupMessages => 'El grupo aún no tiene mensajes';

  @override
  String get selectConversation => 'Elige una conversación para empezar';

  @override
  String get newConversation => 'Nueva conversación';

  @override
  String get newConversationDesc =>
      'Introduce un indicativo para empezar una conversación';

  @override
  String get callsignExample => 'Indicativo, p. ej. BG7ABC';

  @override
  String get start => 'Empezar';

  @override
  String get broadcastMessage => 'Mensaje masivo';

  @override
  String get noStations => 'Sin estaciones';

  @override
  String get broadcastHint =>
      'Cada mensaje se envía por separado a cada destinatario';

  @override
  String broadcastSent(int count) {
    return 'Enviado a $count destinatarios';
  }

  @override
  String get searchCallsign => 'Buscar indicativo…';

  @override
  String get broadcastContentHint => 'Escribe el mensaje a enviar…';

  @override
  String get groupNameHint => 'Introduce el nombre del grupo';

  @override
  String get create => 'Crear';

  @override
  String groupCallsignLine(String call) {
    return 'Indicativo del grupo: $call';
  }

  @override
  String get noMembers => 'Sin miembros';

  @override
  String get inviteMembersHint => 'Toca «Invitar miembros» abajo para añadir';

  @override
  String get remove => 'Quitar';

  @override
  String get inviteMembers => 'Invitar miembros';

  @override
  String get deleteGroup => 'Eliminar grupo';

  @override
  String deleteGroupConfirm(String name) {
    return '¿Eliminar «$name»? Esta acción no se puede deshacer.';
  }

  @override
  String get deleteConversation => 'Eliminar chat';

  @override
  String deleteConversationConfirm(Object call) {
    return '¿Eliminar el historial de chat con $call? Esta acción no se puede deshacer.';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return '¿Borrar el historial de chat de «$name»? Esta acción no se puede deshacer.';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members miembros · $online en línea';
  }

  @override
  String get leaveGroup => 'Salir del grupo';

  @override
  String leaveGroupConfirm(String name) {
    return '¿Salir de «$name»? Dejarás de recibir mensajes de este grupo.';
  }

  @override
  String leftGroup(String name) {
    return 'Has salido de $name';
  }

  @override
  String get leave => 'Salir';

  @override
  String inviteMembersTo(String name) {
    return 'Invitar miembros a $name';
  }

  @override
  String get manualCallsign => 'Introducir indicativo manualmente';

  @override
  String inviteSent(String call) {
    return 'Invitación enviada a $call';
  }

  @override
  String get noMoreOnlineStations => 'No hay más estaciones en línea';

  @override
  String get invited => 'Invitado';

  @override
  String get tapToInvite => 'Toca para invitar';

  @override
  String get done => 'Hecho';

  @override
  String get addContact => 'Añadir contacto';

  @override
  String get addContactDesc =>
      'Introduce un indicativo para añadirlo a los contactos';

  @override
  String contactAdded(String call) {
    return 'Contacto añadido: $call';
  }

  @override
  String get add => 'Añadir';

  @override
  String get stationary => 'Estacionario';

  @override
  String get unknown => 'Desconocido';

  @override
  String get none => 'Ninguno';

  @override
  String get manual => 'Manual';

  @override
  String get management => 'Gestión';

  @override
  String get debugLabel => 'Depuración';

  @override
  String get information => 'Información';

  @override
  String get warning => 'Advertencia';

  @override
  String get errorLabel => 'Error';

  @override
  String countTimes(int count) {
    return '$count veces';
  }

  @override
  String countItems(int count) {
    return '$count';
  }

  @override
  String countEntries(int count) {
    return '$count';
  }

  @override
  String aprsSymbolName(String symbol) {
    String _temp0 = intl.Intl.selectLogic(symbol, {
      'car': 'Coche',
      'police': 'Policía',
      'person': 'Persona',
      'digitalRepeater': 'Repetidor digital',
      'telephone': 'Teléfono',
      'dxCluster': 'Clúster DX',
      'hfGateway': 'Pasarela HF',
      'smallAircraft': 'Avioneta',
      'mobileSatellite': 'Satélite móvil',
      'disabled': 'Accesibilidad',
      'snowmobile': 'Moto de nieve',
      'redCross': 'Cruz Roja',
      'scouts': 'Scouts',
      'house': 'Casa',
      'redX': 'X roja',
      'redDot': 'Punto rojo',
      'fire': 'Fuego',
      'campground': 'Camping',
      'motorcycle': 'Moto',
      'train': 'Tren',
      'fileServer': 'Servidor de archivos',
      'hurricane': 'Huracán',
      'dfTriangle': 'Triángulo DF',
      'postOffice': 'Oficina de correos',
      'largeAircraft': 'Avión grande',
      'weatherStation': 'Estación meteorológica',
      'satelliteDish': 'Antena parabólica',
      'ambulance': 'Ambulancia',
      'bicycle': 'Bicicleta',
      'commandPost': 'Puesto de mando',
      'fireStation': 'Parque de bomberos',
      'horse': 'Caballo',
      'fireTruck': 'Camión de bomberos',
      'glider': 'Planeador',
      'hospital': 'Hospital',
      'fmoStation': 'Estación FMO',
      'jeep': 'Jeep',
      'truck': 'Camión',
      'laptop': 'Portátil',
      'micERepeater': 'Repetidor Mic-E',
      'node': 'Nodo',
      'emergencyOps': 'Operaciones de emergencia',
      'dog': 'Perro',
      'gridSquare': 'Cuadrícula',
      'repeaterTower': 'Torre repetidora',
      'boat': 'Barco',
      'truckStop': 'Área de camiones',
      'semiTrailer': 'Semirremolque',
      'van': 'Furgoneta',
      'waterStation': 'Punto de agua',
      'yagi': 'Antena Yagi',
      'shelter': 'Refugio',
      'rv': 'Autocaravana',
      'weatherSymbol': 'Estación meteorológica',
      'balloon': 'Globo',
      'bus': 'Autobús',
      'shuttle': 'Transbordador espacial',
      'policeCar': 'Coche de policía',
      'sailboat': 'Velero',
      'school': 'Escuela',
      'lodging': 'Alojamiento',
      'hotel': 'Hotel',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': 'Vehículos / transporte',
      'facilities': 'Edificios / servicios',
      'weatherNature': 'Meteorología / naturaleza',
      'emergencyRescue': 'Emergencias / rescate',
      'airWater': 'Aire / agua',
      'communications': 'Comunicaciones / otros',
      'other': 'Otros',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': 'China',
      'KR': 'Corea del Sur',
      'JP': 'Japón',
      'US': 'Estados Unidos',
      'CA': 'Canadá',
      'GB': 'Reino Unido',
      'DE': 'Alemania',
      'FR': 'Francia',
      'IT': 'Italia',
      'ES': 'España',
      'RU': 'Rusia',
      'AU': 'Australia',
      'NZ': 'Nueva Zelanda',
      'BR': 'Brasil',
      'AR': 'Argentina',
      'MX': 'México',
      'ZA': 'Sudáfrica',
      'IN': 'India',
      'TH': 'Tailandia',
      'SG': 'Singapur',
      'MY': 'Malasia',
      'ID': 'Indonesia',
      'PH': 'Filipinas',
      'TW': 'Taiwán',
      'HK': 'Hong Kong',
      'MO': 'Macao',
      'other': 'Desconocido',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => 'Sin ubicación';

  @override
  String get simulatedLocation => 'Ubicación simulada';

  @override
  String get savedLocation => 'Ubicación guardada';

  @override
  String get locationFailed => 'Error de ubicación';

  @override
  String get locationStopped => 'Ubicación detenida';

  @override
  String get locationFixed => 'Ubicación obtenida';

  @override
  String get locationPermission => 'Concede permiso de ubicación…';

  @override
  String get gpsLocating => 'Obteniendo ubicación GPS…';

  @override
  String get webLocationUnsupported =>
      'La ubicación automática no está disponible en la web; introduce las coordenadas a mano';

  @override
  String locationStreamError(String error) {
    return 'Error en el flujo de ubicación: $error';
  }

  @override
  String locationInitError(String error) {
    return 'Error al iniciar la ubicación: $error';
  }

  @override
  String get beaconDisabled => 'Desactivado';

  @override
  String get waitingForLocation => 'Esperando ubicación';

  @override
  String get imminent => 'En breve';

  @override
  String get connTapToConnect =>
      'Sin conexión · Toca conectar para unirte a APRS-IS';

  @override
  String get connManuallyDisconnected =>
      'Sin conexión · Desconectado manualmente';

  @override
  String connAutoReconnect(int seconds) {
    return 'Conexión perdida · Reconectando en ${seconds}s…';
  }

  @override
  String connConnectingTarget(String target) {
    return 'Conectando a $target…';
  }

  @override
  String connOnline(String call) {
    return 'Conectado · $call en línea';
  }

  @override
  String connRetry(int seconds) {
    return 'Error de conexión · Reintentando en ${seconds}s…';
  }

  @override
  String connPositionSent(String call) {
    return 'Conectado · Baliza de posición enviada ($call)';
  }

  @override
  String get connDemoBeacon =>
      'Sin conexión · Baliza de posición registrada (demo)';

  @override
  String get connPasscodeInvalid =>
      'Conectado · Sin verificar (el Passcode puede ser incorrecto)';

  @override
  String get mapTypeAmap => 'AMap';

  @override
  String get mapTypeAmapSatellite => 'AMap satélite';

  @override
  String get mapTypeVector => 'Mapa vectorial';

  @override
  String get amapGroup => 'AMap';

  @override
  String get domesticMaps => 'Mapas de China';

  @override
  String get internationalMaps => 'Mapas globales';

  @override
  String get metricUnits => 'Métrico (km/h, m)';

  @override
  String get coordDisplay => 'Visualización de coordenadas';

  @override
  String mapDefaultCoord(int level) {
    return 'Pekín · Zoom $level';
  }

  @override
  String secondsValue(int count) {
    return '$count s';
  }

  @override
  String get stationSettingsDetail => 'Indicativo, SSID, símbolo y comentario';

  @override
  String get stationIdentity => 'Identidad de la estación';

  @override
  String get aprsCallsignHint => 'Indicativo APRS, p. ej. BV2AAA';

  @override
  String get displayInfo => 'Información de estación';

  @override
  String get ssidSuffix => 'Sufijo SSID';

  @override
  String get chooseSsidSuffix => 'Elegir sufijo SSID';

  @override
  String get mySymbol => 'Mi símbolo';

  @override
  String get moreSymbols => 'Más símbolos';

  @override
  String get allAprsSymbols => 'Todos los símbolos APRS';

  @override
  String get beaconSettingsDetail => 'Fuente de GPS, baliza y ubicación manual';

  @override
  String get locationSource => 'Fuente de ubicación';

  @override
  String get useDeviceLocation => 'Usar la ubicación del dispositivo';

  @override
  String get manualCoordinates => 'Introducir coordenadas a mano';

  @override
  String get locationMode => 'Modo de ubicación';

  @override
  String get settingsLocModeSubtitle => 'Elegir método de ubicación';

  @override
  String get locModeGps => 'Solo GPS';

  @override
  String get locModeGpsDesc => 'Solo satélite; ahorra batería';

  @override
  String get locModeGpsNetwork => 'GPS + red';

  @override
  String get locModeGpsNetworkDesc =>
      'Con ayuda de la red; ubicación más rápida';

  @override
  String get beaconingSection => 'Balizamiento';

  @override
  String get beaconIntervalTip =>
      'Intervalo de envío de la baliza de posición; mínimo 5 segundos';

  @override
  String get beaconContent => 'Contenido de la baliza';

  @override
  String get beaconContentDesc => 'Se envía con cada baliza de posición';

  @override
  String get phoneBattery => 'Batería del teléfono';

  @override
  String get locationStatus => 'Estado de la ubicación';

  @override
  String get relocate => 'Volver a ubicar';

  @override
  String get startGps => 'Iniciar GPS';

  @override
  String get trackingBeaconing =>
      'La ubicación está activa y se siguen enviando balizas';

  @override
  String get manualLocation => 'Ubicación manual';

  @override
  String get latitudeHint => 'Latitud 39.9042';

  @override
  String get longitudeHint => 'Longitud 116.4074';

  @override
  String get invalidLatLng => 'Introduce una latitud y longitud válidas';

  @override
  String myLocationSetGrid(String grid) {
    return 'Ubicación establecida · Cuadrícula $grid';
  }

  @override
  String get applyCoordinates => 'Aplicar coordenadas';

  @override
  String get pickOnMap => 'Elegir en el mapa';

  @override
  String get manualLocationHelp =>
      'Si la ubicación automática no está disponible, introduce coordenadas o elige un punto en el mapa para las balizas y el cálculo de distancias.';

  @override
  String get passcodeTip =>
      'Passcode de acceso a APRS-IS; puedes generarlo en línea. Usa -1 para acceso sin verificar';

  @override
  String get websocketOptional => 'URL de WebSocket (opcional)';

  @override
  String get configChanged => 'Configuración modificada';

  @override
  String get reconnectToApply => 'Reconecta para aplicarlo';

  @override
  String get reconnected => 'Reconectado';

  @override
  String get connectFailedCheckConfig =>
      'Error de conexión; comprueba la configuración';

  @override
  String get rangeFilterDesc =>
      'Recibir solo paquetes de estaciones dentro del rango configurado';

  @override
  String get filterCenterFollows =>
      'Seguir mi ubicación como centro del filtro';

  @override
  String get radiusTip =>
      'Radio de recepción (km); toca «Guardar y aplicar filtro» para aplicar';

  @override
  String get maxStationsTip =>
      'Máximo de estaciones en memoria (ilimitado por defecto; puedes aumentarlo)';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · Radio $radius km';
  }

  @override
  String get receiveFilterDesc2 =>
      'Además del filtro de rango, recibe estaciones por país/región o indicativo exacto';

  @override
  String get receiveCountryDesc =>
      'Recibe todas las estaciones de un país/región por prefijo de indicativo';

  @override
  String get noCountriesSelected => 'Sin países ni regiones seleccionados';

  @override
  String get receiveOthersDesc =>
      'Recibir estaciones especiales cuyo indicativo no coincide con los países elegidos';

  @override
  String get addCountry => 'Añadir país/región';

  @override
  String get chatSettingsDetail => 'Mensajes, contactos y datos de chat';

  @override
  String get messageCountLabel => 'Mensajes';

  @override
  String get manageContacts => 'Gestionar contactos';

  @override
  String deleteAllChatsConfirm(int count) {
    return '¿Eliminar los $count mensajes de chat? Esta acción no se puede deshacer.';
  }

  @override
  String get chatCleared => 'Historial de chat borrado';

  @override
  String get noContacts => 'Sin contactos';

  @override
  String get addOrFavoriteContact =>
      'Toca «Añadir» arriba o marca una estación como favorita en el mapa';

  @override
  String movingWithSpeed(String speed) {
    return 'En movimiento · $speed';
  }

  @override
  String get callsignMin3 => 'El indicativo debe tener al menos 3 caracteres';

  @override
  String get deleteContact => 'Eliminar contacto';

  @override
  String deleteContactConfirm(String call) {
    return '¿Eliminar el contacto $call?';
  }

  @override
  String contactDeleted(String call) {
    return '$call eliminado';
  }

  @override
  String get dataMaintenance => 'Mantenimiento de datos';

  @override
  String get clearAllData => 'Borrar todos los datos';

  @override
  String get clearAllDataIntro =>
      'Esta acción eliminará todos los datos locales siguientes:';

  @override
  String get chatHistory => 'Historial de chat';

  @override
  String get logs => 'Registros';

  @override
  String get irreversibleKeepSettings =>
      'Esta acción no se puede deshacer. La configuración de conexión y el indicativo se conservarán.';

  @override
  String get confirmClearAllData => 'Borrar todos los datos';

  @override
  String get clearAllDataConfirm =>
      '¿Borrar todos los datos locales? Esta acción no se puede deshacer.';

  @override
  String get allDataCleared => 'Todos los datos locales borrados';

  @override
  String get confirmClear => 'Borrar';

  @override
  String get allowLandscape => 'Permitir orientación horizontal';

  @override
  String get packetParseTest => 'Prueba del analizador de paquetes';

  @override
  String get packetParseHint =>
      'Pega un paquete APRS sin procesar, p. ej.:\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Estación de prueba';

  @override
  String get parseAndApply => 'Analizar y aplicar';

  @override
  String get oobePasscodeMissing => 'Passcode sin introducir';

  @override
  String get oobePasscodeMissingDesc =>
      'El Passcode es el código de verificación de APRS-IS para tu indicativo.\n\nEl valor predeterminado -1 permite una conexión sin verificar, pero los mensajes y el chat grupal no funcionarán correctamente.\n\nConsulta el Passcode correcto para tu indicativo en https://aprs.cool/AprsPG.';

  @override
  String get continueAnyway => 'Continuar igualmente';

  @override
  String get fillPasscode => 'Introducirlo';

  @override
  String get oobeMapFeatureDesc =>
      'Teselas de AMap con estaciones APRS y rastros cercanos';

  @override
  String get oobeGpsFeatureDesc =>
      'Obtén tu ubicación y envía balizas de posición a APRS-IS';

  @override
  String get oobeMsgFeatureDesc =>
      'Intercambia mensajes con estaciones, con respuesta automática';

  @override
  String get oobeIsFeatureDesc =>
      'Conéctate a un servidor público y recibe datos de estaciones de todo el mundo';

  @override
  String get oobeBackgroundTip =>
      'Consejo: permite que APRSlocus se ejecute en segundo plano, desactiva la optimización de batería y permite el inicio automático para mantener el balizamiento activo.';

  @override
  String get oobeNextSteps =>
      'Completa la configuración básica en los siguientes pasos. Podrás cambiarla luego en Ajustes.';

  @override
  String get ssidDescShort =>
      'El SSID es el sufijo numérico del indicativo, como -9 en BG7ABC-9';

  @override
  String get ssidOptional => 'Sufijo SSID (opcional)';

  @override
  String get noSsid => 'Sin sufijo (indicativo base)';

  @override
  String fullCallsign(String call) {
    return 'Indicativo completo: $call';
  }

  @override
  String get passcodeImportant => 'El Passcode es importante';

  @override
  String get passcodeImportantDesc =>
      'Un Passcode correcto es necesario para recibir mensajes de grupo y enviar confirmaciones. Con -1 puedes conectarte, pero la mensajería no funcionará correctamente.';

  @override
  String get lookupPasscode => 'Consulta tu Passcode →';

  @override
  String get passcodeLookupHint => 'Introduce tu indicativo, p. ej. BV2AAA';

  @override
  String sendToGroupHint(String group) {
    return 'Enviar a $group…';
  }

  @override
  String sendToCallHint(String call) {
    return 'Enviar a $call…';
  }

  @override
  String get selectMessageReply => 'Toca un mensaje para responder…';

  @override
  String get broadcastShort => 'Masivo';

  @override
  String memberCount(int count) {
    return '$count miembros';
  }

  @override
  String memberCountTap(int count) {
    return '$count miembros · Toca para ver';
  }

  @override
  String get stepRecipients => 'Destinatarios';

  @override
  String get stepContent => 'Mensaje';

  @override
  String get selectAllOnline => 'Seleccionar todos en línea';

  @override
  String get clearSelection => 'Borrar selección';

  @override
  String get onlineOnly => 'Solo en línea';

  @override
  String get noRecipients => 'Sin destinatarios seleccionados';

  @override
  String selectedRecipients(int count) {
    return '$count seleccionados';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return 'Se enviará a $count: $calls';
  }

  @override
  String get stepName => 'Nombre';

  @override
  String get stepMembers => 'Miembros';

  @override
  String get groupChatExplain =>
      'Los chats grupales emiten a un indicativo de grupo, de modo que todos los miembros los reciben. El indicativo de grupo se genera automáticamente y se envían invitaciones a los miembros que elijas.';

  @override
  String get noMembersSelected => 'Sin miembros seleccionados';

  @override
  String get memberBlocked => 'Bloqueado';

  @override
  String get memberJoined => 'Unido';

  @override
  String get memberPending => 'Pendiente';

  @override
  String get memberDeclined => 'Rechazado';

  @override
  String get memberLeft => 'Salió';

  @override
  String get memberTimeout => 'Tiempo agotado';

  @override
  String get unblock => 'Desbloquear';

  @override
  String get block => 'Bloquear';

  @override
  String get groupOwner => 'Propietario';

  @override
  String systemMemberJoined(String call) {
    return '$call se ha unido al grupo';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call ha salido del grupo';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call ha rechazado la invitación';
  }

  @override
  String get copyAllLogs => 'Copiar todos los registros';

  @override
  String copiedLogs(int count) {
    return '$count entradas de registro copiadas';
  }

  @override
  String get clearLogs => 'Borrar registros';

  @override
  String get noLogs => 'Aún no hay registros';

  @override
  String get supportProject => 'Tu apoyo ayuda al proyecto a llegar más lejos';

  @override
  String get continuousIteration => 'Mejora continua';

  @override
  String get continuousIterationDesc =>
      'Mejorando continuamente las funciones y la experiencia de APRSlocus';

  @override
  String get sponsorSupport => 'Apoyo de patrocinadores';

  @override
  String get sponsorMethods => 'Formas de apoyar';

  @override
  String qrCodeTitle(String title) {
    return 'Código QR de $title';
  }

  @override
  String get qrLoadFailed => 'No se pudo cargar la imagen del código QR';

  @override
  String get qrSaveWechat =>
      'Mantén pulsado para guardar · Escanea con WeChat para apoyar';

  @override
  String get tapAnywhereClose => 'Toca en cualquier sitio para cerrar';

  @override
  String vectorMapLoadFailed(String error) {
    return 'Error al cargar el mapa vectorial\n$error';
  }

  @override
  String get loadingVectorMap => 'Cargando mapa vectorial…';

  @override
  String get updateChannel => 'Canal de actualización';

  @override
  String serverReturned(int code) {
    return 'El servidor devolvió $code';
  }

  @override
  String get invalidResponseData => 'Formato de respuesta no válido';

  @override
  String get noVersionsFound => 'No se encontraron versiones';

  @override
  String get noWindowsInstaller =>
      'Esta versión no tiene instalador para Windows';

  @override
  String get noApkInstaller => 'Esta versión no tiene APK';

  @override
  String get connectingEllipsis => 'Conectando…';

  @override
  String downloadHttpError(int code) {
    return 'Error de descarga: HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return 'Descargado $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return 'Paquete descargado en:\n$path\n\nToca «Instalar» para abrir el instalador del sistema.\n\nSi Android bloquea aplicaciones desconocidas, permite que APRSlocus instale aplicaciones desconocidas en los ajustes del sistema.';
  }

  @override
  String windowsInstallHelp(String path) {
    return 'Instalador guardado en:\n$path\n\nToca «Ejecutar ahora» para abrirlo o abre la carpeta que lo contiene.';
  }

  @override
  String get openContainingFolder => 'Abrir carpeta contenedora';

  @override
  String get runNow => 'Ejecutar ahora';

  @override
  String get cannotRunInstaller =>
      'No se pudo iniciar el instalador; ábrelo manualmente desde la carpeta contenedora';

  @override
  String get cannotLaunchInstaller =>
      'No se pudo lanzar el instalador; abre el paquete manualmente';

  @override
  String get openPackageManually => 'Abre el paquete en un gestor de archivos';

  @override
  String cannotOpenPackage(String error) {
    return 'No se pudo abrir el paquete: $error';
  }

  @override
  String get installPermissionTitle =>
      'Permitir la instalación de aplicaciones';

  @override
  String get installPermissionDesc =>
      'APRSlocus no tiene permiso para instalar aplicaciones.\n\nToca «Ajustes», permite que esta aplicación instale aplicaciones desconocidas y vuelve a intentarlo.';

  @override
  String get recheck => 'Comprobar de nuevo';

  @override
  String newVersionTitle(String version) {
    return 'Nueva versión v$version disponible';
  }

  @override
  String repoLatestTitle(String version) {
    return 'Última versión del repositorio v$version';
  }

  @override
  String get checkingLatest => 'Comprobando la última versión…';

  @override
  String get connectingGitCode => 'Conectando al servidor de GitCode';

  @override
  String get noReleaseNotes => 'Sin notas de la versión';

  @override
  String noInstallerHistoryHint(String platform) {
    return 'No hay paquete $platform para esta versión. Elige una versión descargable en el historial.';
  }

  @override
  String get latestVersionLabel => 'Última versión';

  @override
  String packageSize(String platform, String size) {
    return 'Tamaño del paquete $platform: $size';
  }

  @override
  String get updateContents => 'Novedades';

  @override
  String get redownload => 'Volver a descargar';

  @override
  String get downloadInstaller => 'Descargar instalador';

  @override
  String get downloadAndInstall => 'Descargar e instalar';

  @override
  String get localPackageExists => 'Ya hay un paquete descargado';

  @override
  String get packageDeleted => 'Paquete eliminado';

  @override
  String versionCount(int count) {
    return '$count versiones';
  }

  @override
  String get noInstaller => 'Sin paquete';

  @override
  String get download => 'Descargar';

  @override
  String get viewChangelog => 'Ver registro de cambios';

  @override
  String versionChangelog(String version) {
    return 'Registro de cambios de v$version';
  }

  @override
  String get gotIt => 'Entendido';

  @override
  String get leaveAction => 'Salir';

  @override
  String localRepoVersion(Object latest, Object local) {
    return 'Local v$local · Última en el repositorio v$latest';
  }

  @override
  String get unverified => 'Sin verificar';

  @override
  String get passcodeUnverifiedHint => '-1 (sin verificar)';

  @override
  String get passcodeMessageWarning =>
      'Passcode de acceso a APRS-IS. Con -1 no se pueden enviar ni recibir mensajes con normalidad.';

  @override
  String get settingsStationIdentitySubtitle => 'Indicativo, SSID y comentario';

  @override
  String get settingsDisplayInfoSubtitle => 'Mi símbolo y posición actual';

  @override
  String get settingsLocSourceSubtitle => 'Elegir fuente de posición';

  @override
  String get settingsBeaconSubtitle => 'Intervalo de envío y contenido';

  @override
  String get settingsManualLocSubtitle =>
      'Entrada manual o punto en el mapa cuando no hay posición';

  @override
  String get settingsManualLocHint =>
      'Cuando la ubicación automática no esté disponible, introduce coordenadas o elige un punto en el mapa para las balizas y el cálculo de distancias.';

  @override
  String get settingsConnStatusSubtitle => 'Estado e información de conexión';

  @override
  String get settingsServerSubtitle => 'Servidor APRS-IS y passcode';

  @override
  String get settingsFilterSubtitle => 'Centro del filtro y radio';

  @override
  String get settingsReceivePrefSubtitle =>
      'Recibir por país/región o indicativo';

  @override
  String get settingsGeneralSubtitle =>
      'Tema, idioma y visualización de coordenadas';

  @override
  String get settingsMapSubtitle => 'Tipo de mapa y visualización';

  @override
  String get settingsChatStatsSubtitle =>
      'Estadísticas de mensajes y contactos';

  @override
  String get settingsChatManageSubtitle => 'Contactos y datos de chat';

  @override
  String get settingsClearDataSubtitle => 'Eliminar registros locales';

  @override
  String get settingsLabSubtitle => 'Funciones experimentales';

  @override
  String get settingsDevSubtitle => 'Depuración y pruebas';

  @override
  String get settingsFilterHint =>
      'Recibir solo paquetes de estaciones dentro del rango configurado';

  @override
  String get settingsReceivePrefHint =>
      'Además del filtro de rango, recibe estaciones por grupo de país/región o indicativo exacto';

  @override
  String get settingsContribCodeOptimization => 'Optimización de código';

  @override
  String get eggBg2hcb => 'La vida es muy miau-miau~';

  @override
  String get deviceInfoTitle => 'Identificación del dispositivo';

  @override
  String get deviceToCall => 'Indicativo de destino';

  @override
  String get deviceModel => 'Modelo';

  @override
  String get deviceClass => 'Clase de dispositivo';

  @override
  String get deviceFilter => 'Filtro de dispositivos';

  @override
  String get lookupQrz => 'Indicativo en QRZ';

  @override
  String get lookupAprsFi => 'Posición en aprs.fi';

  @override
  String get linkOpenFailed => 'No se pudo abrir el enlace';

  @override
  String get beaconAutoAskTitle =>
      'Conectado: ¿informar de tu posición automáticamente?';

  @override
  String get beaconAutoAskDesc =>
      '¿Quieres que APRSlocus envíe tu posición (baliza) automáticamente mientras esté conectado? Se recomienda para uso móvil. Elige no para solo recibir (podrás enviar una baliza manualmente cuando quieras).';

  @override
  String get beaconAutoYes => 'Informar automáticamente';

  @override
  String get beaconAutoNo => 'No, solo recibir';

  @override
  String get beaconOffChip => 'Informe automático desactivado';

  @override
  String get quickTrackCreate => 'Nuevo grupo de seguimiento';

  @override
  String get quickTrackHint =>
      'Elige estaciones recibidas o escribe indicativos; síguelos en el mapa directamente, sin necesidad de crear un chat grupal.';

  @override
  String get quickTrackName => 'Nombre (opcional)';

  @override
  String get quickTrackPickLabel => 'Elegir estaciones que seguir';

  @override
  String get quickTrackNoStations =>
      'Aún no hay estaciones recibidas; escribe indicativos abajo (separados por comas)';

  @override
  String get quickTrackManualHint =>
      'Escribe indicativos, p. ej. BG7PGW,BG7LMW';

  @override
  String get quickTrackStart => 'Empezar a seguir';

  @override
  String get quickTrackNeedMembers => 'Elige o escribe al menos un indicativo';

  @override
  String get weatherPanelTitle => 'Tiempo · Consejos para radioaficionados';

  @override
  String get weatherPanelSub => 'QWeather · Ubicación actual';

  @override
  String get weatherRefresh => 'Actualizar';

  @override
  String get weatherPowered => 'Datos de QWeather · APRSlocus';

  @override
  String get weatherCurLoc => 'Ubicación actual';

  @override
  String get weatherNoLoc =>
      'Aún sin ubicación: activa el servicio de ubicación en «Mi estación» para ver el tiempo';

  @override
  String get weatherUnavail => 'El servicio meteorológico no está disponible';

  @override
  String get weatherDataFail =>
      'No se pudieron obtener los datos meteorológicos';

  @override
  String get weatherConnFail =>
      'Error de conexión con el servicio meteorológico';

  @override
  String get weatherCloud => 'Nubosidad';

  @override
  String get weatherDew => 'Punto de rocío';

  @override
  String get weatherHumidity => 'Humedad';

  @override
  String get weatherWindDir => 'Dir. del viento';

  @override
  String get weatherWindScale => 'Fuerza';

  @override
  String get weatherWindSpeed => 'Vel. del viento';

  @override
  String get weatherPressure => 'Presión';

  @override
  String get weatherVis => 'Visibilidad';

  @override
  String get weatherPrecip => 'Precipitación';

  @override
  String weatherFeels(String v) {
    return 'Sensación $v°';
  }

  @override
  String weatherObserved(String t) {
    return 'Observado $t';
  }

  @override
  String get hamTitle => 'Consejos para radioaficionados';

  @override
  String get hamNoData =>
      'Cuando se cargue el tiempo, aparecerán consejos de seguridad para instalar antenas, operar y protegerse de los rayos';

  @override
  String get hamStorm1 =>
      'Tormenta eléctrica: ¡NO instales ni uses antenas al aire libre! Desconecta las líneas de alimentación para evitar daños por sobretensión';

  @override
  String get hamStorm2 =>
      'Si ya está instalada, retírala cuanto antes; pasa a escuchar repetidores y HF en interior y mantén el equipo seco';

  @override
  String get hamRain =>
      'Precipitación: lleva cubiertas o cajas estancas, sella los conectores con cinta o termorretráctil y evita que se acumule agua en las líneas';

  @override
  String get hamCold =>
      'Frío / nieve: la capacidad de las baterías de litio baja — lleva repuestos abrigados; vigila la ROE si se forma hielo en la antena';

  @override
  String hamWind(String w) {
    return 'Viento de fuerza $w: asegura bien las antenas con vientos; baja las direccionales y los hilos largos al recoger';
  }

  @override
  String hamHot(String t) {
    return 'Calor de $t°C: hidrátate y evita transmisiones largas a plena potencia que sobrecalienten el equipo';
  }

  @override
  String hamHumid(String h) {
    return 'Humedad del $h%: la humedad reduce el aislamiento y la eficiencia de la antena; hay más pérdidas en VHF/UHF; mantén los conectores sin óxido';
  }

  @override
  String hamFog(String v) {
    return 'Visibilidad reducida ($v km): conduce con cuidado; la niebla puede crear conductos troposféricos — prueba contactos VHF/UHF lejanos';
  }

  @override
  String get hamGood =>
      '¡Buen tiempo para operar! Prueba repetidores y simplex en VHF/UHF; en HF, sigue los cambios de ionosfera por la tarde';

  @override
  String hamWindExtra(String w) {
    return 'Con viento de fuerza $w: asegura igualmente la antena con vientos y cuidado en el campo';
  }

  @override
  String get hamStorm3 =>
      'Se acerca una tormenta: desconecta la línea de antena del equipo, llévala al exterior a una pica de tierra para descargar la estática, apaga y desenchufa la red para que las sobretensiones no entren por la alimentación o la red; no uses antenas exteriores ni teléfonos con cable';

  @override
  String get hamStorm4 =>
      'Alrededor de las tormentas aumentan los chasquidos estáticos (QRN) y sube el ruido de fondo en HF; espera unos 30 minutos tras el cese de los rayos antes de subir antenas y transmitir';

  @override
  String get hamExtreme =>
      'Lluvia torrencial o extrema: atención a riadas, agua embalsada y desprendimientos — no instales en orillas ni en zonas bajas; haz un bucle antigoteo donde la línea entra en la pared';

  @override
  String hamGale(String w) {
    return 'Viento de fuerza $w: ¡prohibido subir a torres o mástiles! Baja o tumba las direccionales y los hilos largos, y revisa vientos, anclajes y retenidas';
  }

  @override
  String get hamIce =>
      'El hielo en antenas y líneas sube la ROE y añade carga: no fuerces a plena potencia, revisa la tensión de los vientos y espera a que se derrita';

  @override
  String get hamFrost =>
      'Por debajo de 0℃: la capacidad de las baterías de litio cae en picado — lleva repuestos abrigados; cuidado con congelación en manos y cara, lleva calentadores de manos';

  @override
  String get hamHeat2 =>
      'El calor hace que amplificadores y fuentes se limiten: baja la potencia, acorta las transmisiones continuas y asegura buena ventilación';

  @override
  String get hamDust =>
      'Tormenta de polvo: la arena fina en conectores y aisladores causa fugas y ruido — usa tapas antipolvo; la fricción seca acumula estática, asegura una buena descarga a tierra';

  @override
  String get hamAir =>
      'Mala calidad del aire: usa mascarilla al aire libre y no te esfuerces de más; los contaminantes sobre los aisladores añaden ruido de fuga, limpia la antena al terminar';

  @override
  String hamDew(String d) {
    return 'Diferencia de punto de rocío de solo $d℃ — el aire está casi saturado: el equipo y las líneas pueden condensar; deja que se atemperen y sequen antes de encender para evitar cortocircuitos';
  }

  @override
  String hamUV(String u) {
    return 'Índice UV $u, alto: protégete del sol en el campo — la exposición prolongada también degrada las fundas de coaxial y las bridas';
  }

  @override
  String hamLowPressure(String p) {
    return 'Presión baja ($p hPa): el tiempo se vuelve inestable — en sesiones largas deja vía de escape y vigila los avisos cercanos';
  }

  @override
  String hamHighPressure(String p) {
    return 'Presión alta y estable ($p hPa): se forman inversiones con facilidad y puede haber conductos troposféricos en VHF/UHF — prueba contactos directos o por repetidor más allá del horizonte';
  }

  @override
  String get hamGrayLine =>
      'Estás en la línea gris del amanecer/atardecer: la propagación en HF de 20/40 m alcanza su máximo — la ventana dorada para DX de larga distancia';

  @override
  String get hamNight =>
      'De noche desaparece la capa D: baja la absorción en 80/40 m con menos ruido — ideal para comunicación regional y de larga distancia nocturna';

  @override
  String get hamRainFade =>
      'La lluvia intensa produce desvanecimiento por lluvia por encima de 1,2 GHz: para microondas y EME, baja de banda o espera a que amaine';

  @override
  String get hamShower =>
      'Los chubascos van y vienen: lleva cubierta de lluvia, vigila el movimiento de las nubes y deja de transmitir antes de quitar la línea';

  @override
  String get hamLevelDanger => 'Seguridad';

  @override
  String get hamLevelWarn => 'Precaución';

  @override
  String get hamLevelGood => 'Propagación';

  @override
  String get hamLevelTip => 'Consejo';

  @override
  String hamMore(String n) {
    return 'Mostrar los $n consejos';
  }

  @override
  String get hamLess => 'Contraer';

  @override
  String get weatherForecast3 => 'Previsión a 3 días';

  @override
  String get weatherDaily15 => 'Ver el tiempo de 15 días';

  @override
  String get weatherDaily15Title => 'Tendencia del tiempo a 15 días';

  @override
  String get weatherToday => 'Hoy';

  @override
  String get weatherTomorrow => 'Mañana';

  @override
  String get weatherDayAfter => 'Pasado mañana';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': 'Lun',
      '2': 'Mar',
      '3': 'Mié',
      '4': 'Jue',
      '5': 'Vie',
      '6': 'Sáb',
      '7': 'Dom',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => 'Amanecer';

  @override
  String get weatherSunset => 'Atardecer';

  @override
  String get weatherUV => 'UV';

  @override
  String get weatherDetails => 'Datos detallados';

  @override
  String get weatherAQIPrimary => 'Principal';

  @override
  String get airExcellent => 'Excelente';

  @override
  String get airGood => 'Buena';

  @override
  String get airModerate => 'Contaminación leve';

  @override
  String get airUnhealthy => 'Contaminación moderada';

  @override
  String get airVeryUnhealthy => 'Contaminación alta';

  @override
  String get airHazardous => 'Contaminación grave';

  @override
  String get weatherAir => 'ICA';

  @override
  String get issStation => 'Estación ISS';

  @override
  String get applyStationFilter => 'Aplicar el filtro de estaciones al mapa';

  @override
  String get stationFilterOn => 'Filtrado por el panel de estaciones';

  @override
  String get stationList => 'Estaciones';

  @override
  String get statsPanel => 'Panel de estadísticas';

  @override
  String get statsOverview => 'Resumen del sistema';

  @override
  String get statsTotalRx => 'Paquetes RX';

  @override
  String get statsTotalTx => 'Paquetes TX';

  @override
  String get statsRate => 'Velocidad';

  @override
  String statsPerMin(String n) {
    return '$n/min';
  }

  @override
  String get statsStationsTotal => 'Estaciones';

  @override
  String get statsCap => 'Capacidad';

  @override
  String get statsConn => 'Enlace';

  @override
  String get statsConnected => 'Conectado';

  @override
  String get statsDisconnected => 'Sin conexión';

  @override
  String get statsMyGrid => 'Mi cuadrícula';

  @override
  String get statsAprslocusUsers => 'Usuarios de APRSlocus';

  @override
  String get statsFarthest => 'Más lejana';

  @override
  String get statsStatusDist => 'Distribución por estado';

  @override
  String get statsTypeDist => 'Distribución por tipo APRS';

  @override
  String get statsGridDist => 'Distribución por cuadrícula';

  @override
  String get statsGridHint =>
      'Estaciones por campo Maidenhead (4 caracteres), ordenadas';

  @override
  String statsGridCount(String n) {
    return '$n cuadrículas';
  }

  @override
  String get statsGridEmpty => 'Aún no hay posiciones de estaciones';

  @override
  String get statsDeviceDist => 'Clases de dispositivo';

  @override
  String get statsOther => 'Otras métricas';

  @override
  String get statsAvgSpeed => 'Velocidad media';

  @override
  String get statsLastHeard => 'Última señal';

  @override
  String get statsPackets => 'Paquetes (recientes)';

  @override
  String get statsNoData => 'Sin datos';

  @override
  String get noStationsFiltered =>
      'Ninguna estación coincide con el filtro actual';

  @override
  String get noStationsFilteredHint =>
      'El filtro o el rango de recepción son demasiado estrechos. Borra el filtro para reintentar; el rango de recepción está en Ajustes.';

  @override
  String get clearStationFilter => 'Borrar filtro';

  @override
  String get clearSearch => 'Borrar búsqueda';

  @override
  String get activeConditions => 'Condiciones activas';

  @override
  String get statsMovingCount => 'En movimiento';

  @override
  String get statsOnlineRate => 'Tasa en línea';

  @override
  String get statsGridCountLabel => 'Cuadrículas';

  @override
  String get maxPackets => 'Límite de paquetes';

  @override
  String get maxPacketsTip =>
      'Cuántos paquetes conservar en la página de paquetes (predeterminado 2000; más usa más memoria)';

  @override
  String get maxTrackPts => 'Límite de puntos de rastro';

  @override
  String get maxTrackPtsTip =>
      'Puntos de rastro por estación (predeterminado 300; determina cuánto atrás llega un rastro; solo se guarda un punto tras 20 m de movimiento)';

  @override
  String get onlineWindow => 'Ventana en línea (minutos)';

  @override
  String get onlineWindowTip =>
      'Una estación sin informar durante más de este tiempo se considera sin conexión (predeterminado 5 minutos)';

  @override
  String get chatRecords => 'Historial de chat';

  @override
  String get chatRecordsCleared => 'Historial de chat borrado';

  @override
  String get deviceCat => 'Dispositivo';

  @override
  String get deviceCatDesc => 'Equipos de radio · próximamente';

  @override
  String get deviceSettings2 => 'Ajustes del dispositivo';

  @override
  String get deviceSettingsSubtitle => 'Conecta tu equipo de radio';

  @override
  String get underConstruction => 'En obras — aún no disponible';

  @override
  String get underConstructionHint =>
      'Esta función aún se está desarrollando. Permanece atento.';

  @override
  String get storageLimit => 'Límites de datos';

  @override
  String get storageLimitSubtitle => 'Cuántos datos conservar localmente';

  @override
  String get connectionCard2 => 'Conexión APRS-IS';

  @override
  String get immersiveMap => 'Mapa inmersivo';

  @override
  String get immersiveMapTip =>
      'Estilo navegación: centrado en ti, rumbo arriba, HUD en las esquinas';

  @override
  String get headingUp => 'Rumbo arriba';

  @override
  String get northUp => 'Norte arriba';

  @override
  String get followMe => 'Seguirme';

  @override
  String get beaconCountdown => 'Próxima baliza';

  @override
  String get beaconOff => 'Desactivado';

  @override
  String get unlocated => 'Sin ubicación';

  @override
  String get platform => 'Plataforma';

  @override
  String get nearbyStations => 'Estaciones cercanas';

  @override
  String get honorWall => 'Honores';

  @override
  String get accountHonors => 'Honores de la cuenta';

  @override
  String get achievementsSection => 'Logros';

  @override
  String get notLit => 'Aún no';

  @override
  String get badgeFallback => 'Insignia';

  @override
  String honoredBadges(String n, String m) {
    return '$n/$m insignias desbloqueadas';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m logros';
  }

  @override
  String get beaconNotConnected => 'Sin conexión';

  @override
  String get beaconWaitingFix => 'Esperando posición';

  @override
  String get beaconSoon => 'Ahora';

  @override
  String beaconNextIn(String s) {
    return 'Próximo informe en $s';
  }

  @override
  String get beaconImminent => 'Informando…';

  @override
  String get notifConnected => 'Conectado';

  @override
  String get notifConnecting => 'Conectando';

  @override
  String get notifDisconnected => 'Sin conexión';

  @override
  String notifOnline(String n) {
    return '$n en línea';
  }

  @override
  String notifRx(String n) {
    return 'RX $n';
  }

  @override
  String notifBeacon(String v) {
    return 'Baliza $v';
  }

  @override
  String get selectAll => 'Seleccionar todo';

  @override
  String get deselectAll => 'Deseleccionar todo';

  @override
  String selectedCount(int n) {
    return '$n seleccionados';
  }

  @override
  String deleteSelected(int n) {
    return 'Eliminar ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return '¿Eliminar los $n chats seleccionados? Esta acción no se puede deshacer.';
  }

  @override
  String get chatManageHint =>
      'Toca un chat para seleccionarlo; mantener pulsado también selecciona';

  @override
  String conversationsDeleted(int n) {
    return '$n chats eliminados';
  }

  @override
  String get stationActions => 'Acciones de estación';

  @override
  String get deleteStation => 'Eliminar estación';

  @override
  String deleteStationConfirm(String name) {
    return '¿Eliminar la estación $name? Se quitará de la lista; volverá a aparecer si se reciben de nuevo sus paquetes.';
  }

  @override
  String get unfavorite => 'Quitar de favoritos';

  @override
  String get copyCallsign => 'Copiar indicativo';

  @override
  String get callsignCopied => 'Indicativo copiado';

  @override
  String get stationDeleted => 'Estación eliminada';

  @override
  String get exportAdif => 'Exportar ADIF';

  @override
  String get exportAdifDesc =>
      'Exporta conversaciones como un archivo de registro ADIF, importable en Log4OM, N3FJP y similares';

  @override
  String get export => 'Exportar';

  @override
  String get adifHint =>
      'Cada registro contiene solo el indicativo y la hora del primer mensaje (UTC); se omiten el modo y la banda';

  @override
  String get adifNoSelection =>
      'Selecciona al menos una conversación para exportar';

  @override
  String adifExported(int n) {
    return '$n registros exportados';
  }

  @override
  String get adifExportFailed =>
      'Error al exportar: comprueba el permiso de almacenamiento o el espacio libre';

  @override
  String adifSavedTo(String path) {
    return 'Guardado en: $path';
  }

  @override
  String get adifCopyPath => 'Copiar ruta';

  @override
  String get adifPathCopied => 'Ruta copiada';

  @override
  String get chatShortLabel => 'Chat';

  @override
  String get adifLogFile => 'Exportar chats como archivo de registro';

  @override
  String get adifOptions => 'Opciones de exportación';

  @override
  String get adifMode => 'Modo (MODE)';

  @override
  String get adifNotWritten => 'Omitir';

  @override
  String get adifModePkt => 'PKT (paquete, recomendado)';

  @override
  String get adifModeFm => 'FM (voz)';

  @override
  String get adifModeData => 'DATA (datos)';

  @override
  String get adifSubModeAprs => 'Añadir SUBMODE=APRS';

  @override
  String get adifBand => 'Banda (BAND)';

  @override
  String get adifStripSsid => 'Escribir solo el indicativo base (sin -SSID)';

  @override
  String get adifPreview => 'Vista previa (registro que se escribirá)';

  @override
  String get adifModeRequiredHint =>
      'La mayoría de los programas de registro (incluido QRZ) exigen MODE; los registros sin él se rechazan';

  @override
  String get adifFreq => 'Frecuencia (FREQ)';

  @override
  String get adifFreqHint => 'En MHz; déjalo vacío para omitir';

  @override
  String get adifFreqInvalid => 'Introduce un número en MHz, p. ej. 144.640';
}
