// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get finish => 'Finish & Connect';

  @override
  String get previous => 'Previous';

  @override
  String get search => 'Search';

  @override
  String get settings => 'Settings';

  @override
  String get greetMorning => 'Good morning, ';

  @override
  String get greetNoon => 'Good noon, ';

  @override
  String get greetAfternoon => 'Good afternoon, ';

  @override
  String get greetEvening => 'Good evening, ';

  @override
  String get greetNight => 'Hello, ';

  @override
  String get about => 'About';

  @override
  String get logout => 'Exit';

  @override
  String get retry => 'Retry';

  @override
  String get all => 'All';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get moving => 'Moving';

  @override
  String get emergency => 'Emergency';

  @override
  String get fixed => 'Fixed';

  @override
  String get infrastructure => 'Digipeater';

  @override
  String get weather => 'Weather';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => 'Mobile';

  @override
  String get favorite => 'Favorite';

  @override
  String get grid => 'Grid';

  @override
  String get callsign => 'Callsign';

  @override
  String get speed => 'Speed';

  @override
  String get altitude => 'Altitude';

  @override
  String get course => 'Course';

  @override
  String get distance => 'Distance';

  @override
  String get bearing => 'Bearing';

  @override
  String get lastSeen => 'Last heard';

  @override
  String get latitude => 'Latitude';

  @override
  String get longitude => 'Longitude';

  @override
  String get station => 'Station';

  @override
  String get stations => 'Stations';

  @override
  String get messages => 'Messages';

  @override
  String get packets => 'Packets';

  @override
  String get map => 'Map';

  @override
  String get home => 'Home';

  @override
  String get connection => 'Connection';

  @override
  String get connected => 'Connected';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get connecting => 'Connecting';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get server => 'Server';

  @override
  String get port => 'Port';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => 'Position beacon';

  @override
  String get beaconInterval => 'Beacon interval (sec)';

  @override
  String get nextBeacon => 'Next beacon';

  @override
  String get beaconsSent => 'Beacons sent';

  @override
  String get symCatVehicles => 'Vehicles / Traffic';

  @override
  String get symCatBuildings => 'Buildings / Facilities';

  @override
  String get symCatNature => 'Weather / Nature';

  @override
  String get symCatAirWater => 'Air / Water';

  @override
  String get symCatComms => 'Comms / Other';

  @override
  String get homeBadgeLabel => 'Badge shown on home';

  @override
  String get homeBadgePickTitle => 'Choose a badge for home';

  @override
  String get homeBadgePickDesc =>
      'Pick one earned badge to keep on your home screen';

  @override
  String get simLocationHint => 'Use a simulated location (no GPS needed)';

  @override
  String get speedTierRules => 'Speed tiers';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get speedTierDesc =>
      'The faster you move, the more often you report; each tier can have its own interval and icon (blank = my symbol).';

  @override
  String get speedTierShortIntervalWarn =>
      'Intervals under 60 s noticeably increase server load; 60 s or more is recommended.';

  @override
  String get addSpeedTier => 'Add speed tier';

  @override
  String get maxSpeedTiers => 'Up to 5 speed tiers';

  @override
  String get iconDefaultMySymbol => 'Icon · Default (my symbol)';

  @override
  String iconNamed(String name) {
    return 'Icon · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return 'Every $sec s';
  }

  @override
  String get tierIdleTitle => 'Edit · Idle/low-speed tier';

  @override
  String get tierSpeedTitle => 'Edit · Speed tier';

  @override
  String get minSpeedKmh => 'Minimum speed (km/h)';

  @override
  String get intervalSeconds => 'Report interval (s)';

  @override
  String get idleTierDesc =>
      'Speeds below the first moving tier are reported with this tier';

  @override
  String get intervalLabel => 'Interval';

  @override
  String get unitSeconds => 's';

  @override
  String get pickBeaconIconDesc =>
      'Pick a beacon icon · \"Default\" keeps my symbol';

  @override
  String get defaultLabel => 'Default';

  @override
  String get deleteThisTier => 'Delete this tier';

  @override
  String get idleTierNotDeletable => 'The idle tier cannot be deleted';

  @override
  String get errMinSpeedInt => 'Minimum speed must be an integer >= 1';

  @override
  String get errIntervalInt => 'Interval must be an integer of at least 5 s';

  @override
  String get errTierDuplicate =>
      'That speed tier already exists; thresholds must be unique';

  @override
  String get wsUrlOptional => 'WebSocket URL (optional)';

  @override
  String get countryUnrestricted =>
      'No country selected · no restriction (all stations)';

  @override
  String get weatherWidget => 'Weather widget';

  @override
  String get groupChatLabel => 'Group chats';

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
    return 'Delete all $n chat messages? This cannot be undone.';
  }

  @override
  String get weatherSimFollowLive => 'Follow live';

  @override
  String get wxClear => 'Clear';

  @override
  String get wxCloudy => 'Cloudy';

  @override
  String get wxOvercast => 'Overcast';

  @override
  String get wxLightRain => 'Light rain';

  @override
  String get wxModerateRain => 'Moderate rain';

  @override
  String get wxHeavyRain => 'Heavy rain';

  @override
  String get wxStormRain => 'Torrential rain';

  @override
  String get wxThunder => 'Thundershower';

  @override
  String get wxSnow => 'Snow';

  @override
  String get wxFog => 'Fog';

  @override
  String get weatherSimTitle =>
      'Weather simulation (preview background/effects/advice)';

  @override
  String get weatherSimDesc =>
      'After choosing, tap the weather pill in the top bar to preview; \"Follow live\" restores real weather';

  @override
  String get restartWizardConfirm =>
      'The first-run wizard will open again so you can reset your callsign, receive area and more.\\nYour current settings are kept; continue using the app after finishing the wizard.';

  @override
  String get restartWizardButton => 'Run again';

  @override
  String get pasteAprsPacketHint =>
      'Paste a raw APRS packet, e.g.\\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test';

  @override
  String beaconsSentCount(String n) {
    return '$n';
  }

  @override
  String get myBadgesAndAchievements => 'My badges and achievements';

  @override
  String get quitApp => 'Quit app';

  @override
  String get quitAppDesc =>
      'Quitting stops location reporting and background reception, and ends the process.';

  @override
  String get symCar => 'Car';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get badgeWall => 'Badge wall';

  @override
  String get achievementWall => 'Achievement wall';

  @override
  String get mapTypeCartoPositron => 'Carto Positron (light vector)';

  @override
  String get mapTypeCarto => 'Carto Light';

  @override
  String get mapTypeCartoDark => 'Carto Dark';

  @override
  String get mapTypeCartoVoyager => 'Carto Voyager';

  @override
  String get mapTypeOsm => 'OSM Standard';

  @override
  String get mapTypeOsmHot => 'OSM Humanitarian';

  @override
  String get mapTypeOpenTopo => 'OpenTopo Terrain';

  @override
  String get mapTypeEsriStreet => 'Esri Streets';

  @override
  String get mapTypeEsriSat => 'Esri Imagery';

  @override
  String get simulatedKeepAlive => 'Simulated location · keep-alive';

  @override
  String get symCatEmergency => 'Emergency';

  @override
  String get symSmallAircraft => 'Small aircraft';

  @override
  String myPositionSet(String grid) {
    return 'My position set, grid $grid';
  }

  @override
  String get tierIdleShort => 'Idle/low';

  @override
  String get symHouse => 'House';

  @override
  String get symPerson => 'Person';

  @override
  String get symTruck => 'Truck';

  @override
  String get symBicycle => 'Bicycle';

  @override
  String get symRv => 'RV';

  @override
  String get symWxStation => 'Weather station';

  @override
  String get symPolice => 'Police';

  @override
  String get symMotorcycle => 'Motorcycle';

  @override
  String get symSemi => 'Semi-trailer';

  @override
  String get symVan => 'Van';

  @override
  String get symJeep => 'Jeep';

  @override
  String get symBus => 'Bus';

  @override
  String get symTruckStop => 'Truck stop';

  @override
  String get symTrain => 'Train';

  @override
  String get symFireTruck => 'Fire truck';

  @override
  String get symPoliceCar => 'Police car';

  @override
  String get symSnowmobile => 'Snowmobile';

  @override
  String get symYagi => 'Yagi';

  @override
  String get symHospital => 'Hospital';

  @override
  String get symAmbulance => 'Ambulance';

  @override
  String get symFireStation => 'Fire station';

  @override
  String get symSchool => 'School';

  @override
  String get symMotel => 'Motel';

  @override
  String get symHotel => 'Hotel';

  @override
  String get symLaptop => 'Laptop';

  @override
  String get symPostOffice => 'Post office';

  @override
  String get symWeather => 'Weather';

  @override
  String get symWater => 'Water station';

  @override
  String get symHurricane => 'Hurricane';

  @override
  String get symHorse => 'Horseback';

  @override
  String get symDog => 'Dog';

  @override
  String get symCamping => 'Camping';

  @override
  String get symShelter => 'Shelter';

  @override
  String get symRedCross => 'Red Cross';

  @override
  String get symFireAlarm => 'Fire alarm';

  @override
  String get symEmergCenter => 'Emergency center';

  @override
  String get symCmdCenter => 'Command center';

  @override
  String get symHandicap => 'Handicapped';

  @override
  String get symBigAircraft => 'Large aircraft';

  @override
  String get symGlider => 'Glider';

  @override
  String get symBalloon => 'Balloon';

  @override
  String get symShip => 'Ship';

  @override
  String get symSailboat => 'Sailboat';

  @override
  String get symMobileSat => 'Mobile satellite';

  @override
  String get symSatAntenna => 'Satellite antenna';

  @override
  String get symDigi => 'Digital repeater';

  @override
  String get symDigiTower => 'Repeater tower';

  @override
  String get symMicE => 'Mic-E repeater';

  @override
  String get symNode => 'Node';

  @override
  String get symDxCluster => 'DX cluster';

  @override
  String get symHfGateway => 'HF gateway';

  @override
  String get symFileServer => 'File server';

  @override
  String get symTelephone => 'Telephone';

  @override
  String get symGrid => 'Grid';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'FMO station';

  @override
  String get filter => 'Range filter';

  @override
  String get filterRadius => 'Radius (km)';

  @override
  String get maxStations => 'Max stations';

  @override
  String get receiveFilter => 'Callsign filter';

  @override
  String get receiveCountries => 'Countries';

  @override
  String get receiveOthers => 'Other stations';

  @override
  String get darkMode => 'Dark mode';

  @override
  String get themeColor => 'Theme color';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

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
  String get languageEs => 'Spanish';

  @override
  String get displaySettings => 'Display settings';

  @override
  String get uiScale => 'UI scale';

  @override
  String get reloadUi => 'Reload UI';

  @override
  String get reloadDone => 'Reloaded';

  @override
  String get mapType => 'Map type';

  @override
  String get unit => 'Unit';

  @override
  String get coordDatum => 'Datum';

  @override
  String get stationSettings => 'Station settings';

  @override
  String get connectionSettings => 'Connection settings';

  @override
  String get chatSettings => 'Chat settings';

  @override
  String get dataSettings => 'Data settings';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get sponsors => 'Sponsors';

  @override
  String get sponsorsThanks => 'Thanks to every supporter';

  @override
  String get send => 'Send';

  @override
  String get receive => 'Receive';

  @override
  String get clear => 'Clear';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied';

  @override
  String get version => 'Version';

  @override
  String get location => 'Location';

  @override
  String get gpsStatus => 'GPS status';

  @override
  String get myLocation => 'My location';

  @override
  String get track => 'Track';

  @override
  String get forwardingPath => 'Path';

  @override
  String get relatedStations => 'Related stations';

  @override
  String get openInMap => 'View on map';

  @override
  String get navigate => 'Navigate';

  @override
  String get messageSent => 'Message sent';

  @override
  String get enterMessage => 'Type a message';

  @override
  String get noData => 'No data';

  @override
  String get searchHint => 'Search callsign / type / grid / comment…';

  @override
  String get notFound => 'No stations found';

  @override
  String get totalStations => 'Total';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortCall => 'Callsign';

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortDistance => 'Distance';

  @override
  String get sortStatus => 'Status';

  @override
  String get typeFilter => 'Type';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => 'Delete this item?';

  @override
  String get confirmRestartOobe =>
      'This will re-open the setup wizard to configure callsign, receive region, etc.\nYour current settings will be kept.';

  @override
  String get restartWizard => 'Run setup wizard again';

  @override
  String get restartWizardTitle => 'Run setup wizard again?';

  @override
  String get oobeFilterTitle => 'Choose receive region';

  @override
  String get oobeFilterDesc =>
      'Tick the countries/regions to receive. Leave all unselected to receive every station with no restriction.';

  @override
  String get oobeWelcomeTitle => 'Welcome to APRSlocus';

  @override
  String get oobeWelcomeRealMap => 'Live map';

  @override
  String get oobeWelcomeGps => 'GPS position beaconing';

  @override
  String get oobeWelcomeMsg => 'APRS messages';

  @override
  String get oobeWelcomeIs => 'APRS-IS feed';

  @override
  String get oobeCallTitle => 'Set callsign';

  @override
  String get oobeSymbolTitle => 'Choose station symbol';

  @override
  String get oobeServerTitle => 'Connect to APRS-IS server';

  @override
  String get weatherData => 'Weather data';

  @override
  String get fmoInfo => 'FMO info';

  @override
  String get aprslocusInfo => 'APRSlocus info';

  @override
  String get locationInfo => 'Location';

  @override
  String get recentPackets => 'Recent packets';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get copyCoords => 'Copy coords';

  @override
  String get copyGrid => 'Copy grid';

  @override
  String get sender => 'Sender';

  @override
  String get time => 'Time';

  @override
  String get message => 'Message';

  @override
  String get groupChat => 'Group chat';

  @override
  String get newGroup => 'New group';

  @override
  String get sendTo => 'Send to';

  @override
  String get filterRule => 'Filter rule';

  @override
  String get saveAndApply => 'Save & apply filter';

  @override
  String get useMyLocation => 'Use my position as filter center';

  @override
  String get noFixYet => 'No location fix yet; current position is unavailable';

  @override
  String get invalidCoords => 'Enter valid latitude, longitude, and radius';

  @override
  String get filterSaved => 'Filter saved and applied';

  @override
  String get stationsShown => 'Stations';

  @override
  String get settingsDesc => 'Configure station, location & connection';

  @override
  String get radioCat => 'Station';

  @override
  String get radioCatDesc => 'Callsign · SSID · Symbol';

  @override
  String get beaconCat => 'Beaconing';

  @override
  String get beaconCatDesc => 'GPS · Beaconing · Manual position';

  @override
  String get connectionCat => 'Connection';

  @override
  String get connectionCatDesc => 'Server · Range filter';

  @override
  String get displayCat => 'Display';

  @override
  String get displayCatDesc => 'Coords · Theme';

  @override
  String get chatCat => 'Chat';

  @override
  String get chatCatDesc => 'History · Contacts';

  @override
  String get dataCat => 'Data';

  @override
  String get dataCatDesc => 'Clear local data';

  @override
  String get advancedCat => 'Advanced';

  @override
  String get advancedCatDesc => 'Lab · Developer';

  @override
  String get updateCat => 'Update';

  @override
  String get updateCatDesc => 'Check for updates';

  @override
  String get checkUpdate => 'Check update';

  @override
  String get myStationSettings => 'My station';

  @override
  String get myStationSettingsDesc => 'Callsign · SSID · Symbol · Beaconing';

  @override
  String get oobeWelcomeDesc => 'Start configuring your APRS station';

  @override
  String get oobeCallDesc => 'Enter your callsign';

  @override
  String get oobeSymbolDesc =>
      'The symbol represents your station type and is sent with position beacons';

  @override
  String get oobeServerDesc =>
      'Connect to receive APRS station data worldwide. The default settings work as-is.';

  @override
  String get wizard => 'Setup wizard';

  @override
  String get setStep => 'Step';

  @override
  String get chooseSymbol => 'Choose station symbol';

  @override
  String get settingsSubtitle => 'Map coordinates & display preferences';

  @override
  String get stationSettingsSubtitle => 'Callsign, symbol & beaconing';

  @override
  String get connectionSettingsSubtitle => 'APRS-IS server & receive range';

  @override
  String get chatSettingsSubtitle => 'Message history & contacts';

  @override
  String get dataSettingsSubtitle => 'Local data management';

  @override
  String get advancedSettingsSubtitle => 'Lab & developer tools';

  @override
  String get stationListTitle => 'Stations';

  @override
  String get filters => 'Filters';

  @override
  String get clearAll => 'Clear all';

  @override
  String get statusFilter => 'Status';

  @override
  String get typeGroup => 'Type';

  @override
  String get appFilter => 'App';

  @override
  String get mapMenu => 'Map menu';

  @override
  String get mapTypeTitle => 'Map type';

  @override
  String get selectMapType => 'Select map type';

  @override
  String get showTrails => 'Show tracks';

  @override
  String get showStations => 'Show stations';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutSubtitle => 'APRS tracking & mapping';

  @override
  String get author => 'Author';

  @override
  String get codeContributions => 'Code contributions';

  @override
  String get codeContributionI18n => 'Internationalization / English UI';

  @override
  String get codeContributionZhTw => 'Traditional Chinese UI';

  @override
  String get codeContributionTranslation => 'Translation';

  @override
  String get dataSourceTxHint =>
      'You can enable several links at once to receive from all of them, but **only one transmits** (the dot on the right). Sending the same callsign over two links would duplicate packets.';

  @override
  String get dataSourceTxBadge => 'TX';

  @override
  String get dataSourceIgateHint =>
      'To run a gateway (relay RF packets to the internet), enable both APRS-IS and TNC/audio, then turn on “Gateway” below.';

  @override
  String get igateTitle => 'Gateway (iGate)';

  @override
  String get igateSubtitle => 'Relay packets heard on RF into APRS-IS';

  @override
  String get igateEnable => 'Enable gateway';

  @override
  String get igateHint =>
      'Packets heard on RF are forwarded to APRS-IS, tagged with qAr/qAR and your callsign to mark their origin. Requires both APRS-IS and an RF source (TNC / audio) enabled.';

  @override
  String get igateNeedRf =>
      'No RF source yet: tick TNC or audio under “Data source” above, otherwise the gateway has nothing to relay from.';

  @override
  String get igateNeedIs =>
      'APRS-IS is not enabled: tick it above, otherwise the gateway has nowhere to relay to.';

  @override
  String get igateTwoWay => 'Two-way gateway (forward messages to RF)';

  @override
  String get igateTwoWayHint =>
      'When on, this **transmits on RF**: only point-to-point messages addressed to a station recently heard on RF are forwarded (broadcasts such as positions/weather are not, to avoid filling the channel). When off, RF→IS only.';

  @override
  String get igateStatToIs => 'Relayed → APRS-IS';

  @override
  String get igateStatToRf => 'Relayed → RF';

  @override
  String get igateStatDup => 'Duplicates dropped';

  @override
  String get igateResetStats => 'Reset counters';

  @override
  String grpSysJoined(String call) {
    return '$call joined the group';
  }

  @override
  String grpSysLeft(String call) {
    return '$call left the group';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call asked to join';
  }

  @override
  String grpSysDeclined(String call) {
    return '$call declined the invite';
  }

  @override
  String get grpInviteTitle => 'Group invite';

  @override
  String grpInviteBody(String from, String name) {
    return '$from invited you to “$name”';
  }

  @override
  String get grpNameInvalid =>
      'Group name cannot be empty or contain a colon or newline';

  @override
  String grpNameTooLong(int max) {
    return 'Group name is limited to $max characters (longer makes the invite exceed the APRS message limit)';
  }

  @override
  String grpInviteSent(int n) {
    return 'Invite sent to $n member(s)';
  }

  @override
  String get grpSelfPending => 'Waiting for the owner';

  @override
  String get deviceOverviewTitle => 'Devices';

  @override
  String get deviceOverviewSubtitle => 'Data source, link status and self-test';

  @override
  String get deviceCurrentLink => 'Current link';

  @override
  String get deviceCurrentLinkDesc =>
      'Read-only summary — edit parameters in the sub-pages';

  @override
  String get deviceEntries => 'Devices & parameters';

  @override
  String get deviceEntriesDesc =>
      'One sub-page per link, each with its own settings';

  @override
  String get tncDeviceTitle => 'TNC device & parameters';

  @override
  String get tncDeviceDesc =>
      'Bluetooth/serial binding, init string, KISS parameters and TX self-test';

  @override
  String get deviceLogTitle => 'Link log';

  @override
  String get deviceLogDesc =>
      'Shows the log of the current source (TNC / audio switches automatically)';

  @override
  String get tncInitTitle => 'TNC init string';

  @override
  String get tncInitSubtitle =>
      'Sent line by line after connecting (same as APRSdroid kiss.init)';

  @override
  String get tncInitTip =>
      'If the TNC receives but will not transmit, try here first: many Bluetooth/serial TNC modules boot into command mode and need KISS ON / RESTART before they will forward in KISS. One command per line (CRLF is appended automatically).';

  @override
  String get tncInitDelay => 'Delay per line (ms)';

  @override
  String get tncInitDelayTip =>
      'Wait between lines. Modules need time to process commands; too short drops them';

  @override
  String get tncInitSendAction => 'Send init string now';

  @override
  String tncInitSent(int n) {
    return 'Sent $n init line(s)';
  }

  @override
  String get tncInitEmpty => 'No init string configured';

  @override
  String get tncPushParams => 'Push KISS parameters on connect';

  @override
  String get tncPushParamsTip =>
      'Off by default (same as APRSdroid). When on, the values above are pushed to the TNC on connect, overriding its own configuration — inappropriate values can make it back off forever without transmitting, so enable only if you want centralised control.';

  @override
  String get tncTxTestTitle => 'TX self-test';

  @override
  String get tncTxTestSubtitle =>
      'Writes one test frame to the TNC to tell link problems from TNC problems';

  @override
  String get tncTxTestHint =>
      'It sends a status frame (no coordinates), so it will not move your station on aprs.fi. If it reports \"written\" but nothing is transmitted, the problem is on the TNC side: try the init string (KISS ON / RESTART) first, then check TxDelay and channel occupancy.';

  @override
  String get tncTxTestAction => 'Write test frame';

  @override
  String get tncTxTestOkPrefix => 'Written';

  @override
  String tncTxTestOk(String n) {
    return 'Written to the TNC ($n frames total). If the radio still does not transmit, the issue is on the TNC side: try the init string or check TxDelay.';
  }

  @override
  String tncTxTestFail(String err) {
    return 'Not written: $err';
  }

  @override
  String get tncNeedConnected => 'Connect the TNC first';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 chars · $bytes/512 bytes total';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return 'This message is $chars characters, over the APRS spec limit of 67. Most clients will still show it, but some clients/gateways truncate or reject it, so the other station may not be able to parse it. Send anyway?';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return 'The packet is $bytes bytes, over the 512-byte APRS-IS line limit. The server may drop it entirely (not even the header arrives). Please shorten by about $over bytes.';
  }

  @override
  String get msgSendAnyway => 'Send anyway';

  @override
  String get msgSpecLimitHint =>
      'The APRS spec recommends keeping a message under 67 characters: longer text may be truncated or fail to parse in some clients.';

  @override
  String get msgBlockedTooLong =>
      'Send blocked: packet exceeds the APRS-IS limit';

  @override
  String get beaconRfBeaconOff => 'RF beacon is off';

  @override
  String get beaconRfEnableHint =>
      'Automatic transmission on an RF source requires the “RF beacon” switch. Until then no position is transmitted automatically (and the countdown does not run).';

  @override
  String get beaconRfEnableAction => 'Enable RF beacon';

  @override
  String get beaconRfEnabled => 'RF beacon enabled — will transmit on schedule';

  @override
  String get beaconRfEnableWarn =>
      'Transmission uses your callsign — operate within your licence';

  @override
  String get diagTitle => 'Link self-test';

  @override
  String get diagSubtitle =>
      'Checks protocol, permissions and devices layer by layer';

  @override
  String get diagRun => 'Run self-test';

  @override
  String get diagRunning => 'Testing…';

  @override
  String diagPassed(int n) {
    return '$n passed';
  }

  @override
  String diagFailed(int n) {
    return '$n failed';
  }

  @override
  String get diagHint =>
      'Protocol loops run without a radio: rule out software first, then check devices and wiring';

  @override
  String get diagTncSection => 'TNC (KISS / AX.25)';

  @override
  String get diagAudioSection => 'Audio (AFSK 1200)';

  @override
  String get diagKissEscape => 'KISS escaping';

  @override
  String get diagKissEscapeFail =>
      'KISS unescaping failed (software issue — changing hardware will not help)';

  @override
  String get diagAx25 => 'AX.25 framing';

  @override
  String get diagAx25Fail => 'AX.25 encoding failed (malformed packet)';

  @override
  String diagAx25Mismatch(String got) {
    return 'AX.25 round-trip mismatch, decoded: $got';
  }

  @override
  String get diagFcs => 'FCS check';

  @override
  String get diagFcsFail =>
      'FCS check is wrong (a one-byte change must be rejected)';

  @override
  String get diagTncLoopback => 'TNC protocol loop';

  @override
  String diagTncLoopbackOk(int len) {
    return 'KISS/AX.25 round-trip identical ($len bytes)';
  }

  @override
  String get diagAfskLoopback => 'AFSK modem loop';

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return 'Modulate → demodulate identical ($samples samples @${rate}Hz)';
  }

  @override
  String diagAfskLoopbackFail(int n) {
    return 'Decoded $n frame(s) — expected 1';
  }

  @override
  String get diagAfskLevelFail =>
      'Waveform level too low (output is nearly silent)';

  @override
  String get diagPlatform => 'Platform support';

  @override
  String diagPlatformOk(String name) {
    return 'Available · backend $name';
  }

  @override
  String get diagTncPlatformNo =>
      'TNC links are not supported on this platform';

  @override
  String get diagAudioPlatformWarn =>
      'No real-time audio — WAV file mode is still available';

  @override
  String get diagNoRealtime => 'not real-time';

  @override
  String get diagPermission => 'Mic permission';

  @override
  String get diagPermissionOk => 'Granted';

  @override
  String get diagSkipped => 'Skipped (unsupported platform)';

  @override
  String get diagCapture => 'Audio capture';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return 'Received $bytes bytes @${rate}Hz';
  }

  @override
  String get diagCaptureNoData =>
      'No audio data received — check the input device and permissions';

  @override
  String diagCaptureFailed(String err) {
    return 'Could not start capture: $err';
  }

  @override
  String get diagSpeaker => 'Speaker output';

  @override
  String get diagSpeakerOk => 'Test tone played';

  @override
  String diagSpeakerFail(String err) {
    return 'Playback failed: $err';
  }

  @override
  String get diagFileIo => 'WAV file I/O';

  @override
  String diagFileIoOk(int rate) {
    return 'Write → read → decode identical @${rate}Hz';
  }

  @override
  String diagFileWriteFail(String err) {
    return 'File write failed: $err';
  }

  @override
  String get diagFileReadFail => 'File read failed';

  @override
  String get diagFileDecodeFail =>
      'No packet decoded from the file (maybe not an AFSK 1200 recording)';

  @override
  String get connAudioSourceHint =>
      'Audio mode does not use the server, filters or KISS settings';

  @override
  String get testTxTitle => 'Test transmit';

  @override
  String get testTxDesc =>
      'Sends a status packet to prove the link really reaches the air';

  @override
  String get testTxAction => 'Transmit test frame';

  @override
  String get testTxSent => 'Test frame handed to the link';

  @override
  String testTxFail(String err) {
    return 'Test frame failed: $err';
  }

  @override
  String get testTxNeedsConnect => 'Connect the link first';

  @override
  String get testTxHint =>
      'This **really transmits** (a status packet, no coordinates). Make sure you are operating within your licence and callsign';

  @override
  String get audioStatsTitle => 'Audio statistics';

  @override
  String audioStatRx(int n) {
    return '$n frames received';
  }

  @override
  String audioStatTx(int n) {
    return '$n frames sent';
  }

  @override
  String audioStatDrop(int n) {
    return '$n bytes dropped while transmitting';
  }

  @override
  String get audioRestart => 'Restart audio link';

  @override
  String get audioTxDisabled => '\"Allow transmit\" is off — receiving only';

  @override
  String get audioLoopbackHint =>
      'The self-test really modulates and demodulates; \"dropped while transmitting\" is normal half-duplex behaviour';

  @override
  String get notifAudioConnected => 'Audio link online';

  @override
  String get notifAudioDisconnected => 'Audio link disconnected';

  @override
  String connConnectingAudio(String name) {
    return 'Opening audio ($name)…';
  }

  @override
  String connAudioConnected(String rate) {
    return 'Audio link online · $rate';
  }

  @override
  String connRetryAudio(int seconds) {
    return 'Could not open audio · retrying in ${seconds}s…';
  }

  @override
  String connRetryAudioDetail(String detail, int seconds) {
    return 'Audio failed ($detail) · retrying in ${seconds}s…';
  }

  @override
  String connAudioLinkLost(int seconds) {
    return 'Audio link lost · reconnecting in ${seconds}s…';
  }

  @override
  String connAudioPositionSent(String call) {
    return 'Sent over audio · position transmitted ($call)';
  }

  @override
  String get dataSourceAudio => 'Audio (soundcard)';

  @override
  String get dataSourceAudioDesc =>
      'AFSK 1200 to/from a radio via mic/speaker or a soundcard cable';

  @override
  String get audioSettings => 'Audio (soundcard TNC)';

  @override
  String get audioSettingsSubtitle =>
      'Send and receive AFSK 1200 packets with your soundcard';

  @override
  String get audioBackend => 'Audio backend';

  @override
  String get audioUnsupported =>
      'Real-time audio is not supported on this platform (WAV file mode is available)';

  @override
  String get audioNeedPermission =>
      'Microphone permission (RECORD_AUDIO) is required — grant it and try again';

  @override
  String get audioCaptureTitle => 'Audio capture';

  @override
  String get audioCaptureDesc => 'Demodulate AFSK 1200 from the mic/line input';

  @override
  String get audioCaptureStart => 'Start capture';

  @override
  String get audioCaptureStop => 'Stop capture';

  @override
  String get audioSampleRate => 'Sample rate';

  @override
  String get audioSampleRateTip =>
      '22050 Hz is the usual soundcard-TNC rate; use 44100/48000 if unsupported. Changing it restarts capture';

  @override
  String get audioLevel => 'Input level';

  @override
  String get audioLevelTip =>
      'The meter rises with a signal; \"Demod locked\" lights up when AFSK is detected';

  @override
  String get audioSynced => 'Demod locked';

  @override
  String get audioUnlocked => 'Not locked';

  @override
  String audioBadFrames(int n) {
    return '$n aborted decodes (noise / out of sync)';
  }

  @override
  String get audioBaud => 'Bit rate';

  @override
  String get audioTones => 'Tones (mark/space)';

  @override
  String get audioTxTitle => 'Audio transmit';

  @override
  String get audioTxDesc => 'Listens before transmitting to avoid collisions';

  @override
  String get audioTxEnabled => 'Allow transmit';

  @override
  String get audioTxEnabledTip =>
      'When off, receive only — handy if you just want to monitor beacons';

  @override
  String get audioTxDelayTip =>
      'Preamble length: lets the far-end demod lock and the radio key up';

  @override
  String get audioToneMark => 'Mark tone (Hz)';

  @override
  String get audioToneSpace => 'Space tone (Hz)';

  @override
  String get audioMarkTip =>
      'Bell 202 specifies mark 1200 Hz / space 2200 Hz; the tolerance is only a few Hz';

  @override
  String get audioSpaceTip =>
      'Space tone. Together with mark it sets the FSK shift (1000 Hz nominal)';

  @override
  String get audioBaudTip =>
      'APRS on VHF is always 1200 bd (Bell 202); 300 bd is for HF';

  @override
  String get audioTxDelayLabel => 'Tx preamble (ms)';

  @override
  String get audioTnc2Tip =>
      'Format SRC>DEST,PATH:info, e.g. BG7LZQ-9>APALOC:>TEST';

  @override
  String get audioCsmaWait => 'Wait for a clear channel (ms)';

  @override
  String get audioCsmaWaitTip =>
      'How long to wait when the channel is busy; 0 = transmit immediately';

  @override
  String get audioStopTx => 'Stop transmit';

  @override
  String get audioWavTitle => 'WAV file mode';

  @override
  String get audioWavDesc =>
      'Decode a recording offline, or export a packet as audio';

  @override
  String get audioWavPath => 'File path';

  @override
  String get audioWavDecodeAction => 'Decode this WAV';

  @override
  String get audioWavExportAction => 'Export this packet';

  @override
  String get audioWavTnC2 => 'Packet to export (TNC2)';

  @override
  String get audioWavNone =>
      'No packets decoded (maybe not an AFSK 1200 recording)';

  @override
  String audioWavFound(int n) {
    return 'Decoded $n packet(s)';
  }

  @override
  String audioWavWritten(String path) {
    return 'Written to $path';
  }

  @override
  String audioWavFailed(String err) {
    return 'File I/O failed: $err';
  }

  @override
  String connTncConnected(String arg) {
    return 'TNC connected · $arg';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC connected · position sent ($arg)';
  }

  @override
  String connRetryTnc(int n) {
    return 'TNC connection failed · retrying in ${n}s…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'TNC connection failed ($e) · retrying in ${n}s…';
  }

  @override
  String connTncLinkLost(int n) {
    return 'TNC link lost · reconnecting in ${n}s…';
  }

  @override
  String get tncErrNoDevice => 'no TNC device bound';

  @override
  String get tncErrUnsupported => 'unsupported on this platform';

  @override
  String get tncErrNotConnected => 'link not connected';

  @override
  String get tncErrOpenRead => 'cannot open device for reading';

  @override
  String get tncErrOpenWrite =>
      'cannot open device for writing — Windows COM ports are exclusive; check for another app holding it';

  @override
  String get tncErrBadFormat => 'malformed packet';

  @override
  String get tncErrFrameTooLong => 'frame exceeds the size limit';

  @override
  String get tncErrTimeout => 'timed out';

  @override
  String get translateMyLang => 'My language';

  @override
  String get translateMyLangHint =>
      'Messages from the other side are translated into this';

  @override
  String get translatePeerLang => 'The other party\'s language';

  @override
  String get translatePeerUnknownHint =>
      'Detected automatically from their messages';

  @override
  String get translateLearned => 'Auto-detected';

  @override
  String get translatePeerUnknown =>
      'The other party\'s language is still unknown — set it in translation settings, or it will be detected after a few of their messages';

  @override
  String get translateSideIncoming => 'received';

  @override
  String get translateSideOutgoing => 'sent';

  @override
  String get translateToMeTag => 'for me';

  @override
  String get translateToPeerTag => 'what they read';

  @override
  String get translateContrast => 'Show original and translation together';

  @override
  String get translateContrastTip =>
      'When off only the translation shows (long-press still reveals the original)';

  @override
  String get translateProviderFree => 'Free (no key needed)';

  @override
  String get translateProviderFreeDesc =>
      'Works out of the box · uses a public endpoint that may be rate-limited or unstable';

  @override
  String translateFreeFailed(String e) {
    return 'The free endpoint is unavailable ($e) · switch to Google / Baidu / a custom endpoint in settings';
  }

  @override
  String get translateProviderAuto => 'Automatic (recommended)';

  @override
  String get translateProviderAutoDesc =>
      'Tries several keyless endpoints in turn and keeps the first real translation';

  @override
  String get translateProviderGooglePublic =>
      'Google public endpoint (keyless)';

  @override
  String get translateProviderGooglePublicDesc =>
      'Good quality, but may be rate-limited (observed 429)';

  @override
  String get translateProviderMyMemory => 'MyMemory (keyless)';

  @override
  String get translateProviderMyMemoryDesc =>
      'Official free API, but it is a translation memory: returns the source text when it has no match';

  @override
  String get translateProviderLibre => 'LibreTranslate (self-hostable)';

  @override
  String get translateProviderLibreDesc =>
      'Open source and most reliable self-hosted; public instances now need a key and often lack Chinese';

  @override
  String get translateLibreUrl => 'Instance URL';

  @override
  String get translateLibreKey =>
      'Instance API key (needed for public instances; leave empty when self-hosted)';

  @override
  String get translateUsedProvider => 'Actually used';

  @override
  String get translateUntranslated =>
      'The endpoint did not actually translate (it returned the source text) — tried the next one';

  @override
  String translateAutoAllFailed(String e) {
    return 'All keyless endpoints failed ($e) · switch to a Google/Baidu key or your own instance in settings';
  }

  @override
  String get translateLangUnsupported =>
      'This provider cannot translate into that language · try “Automatic” or another provider';

  @override
  String get translateLangScopeNote =>
      'Providers differ in language coverage (e.g. Baidu standard supports Indonesian “id”, but not every direction) — when unsupported, the app suggests Automatic or another provider';

  @override
  String get langNameZh => 'Chinese (Simplified)';

  @override
  String get langNameZhTw => 'Chinese (Traditional)';

  @override
  String get langNameEn => 'English';

  @override
  String get langNameJa => 'Japanese';

  @override
  String get langNameKo => 'Korean';

  @override
  String get langNameEs => 'Spanish';

  @override
  String get langNameFr => 'French';

  @override
  String get langNameDe => 'German';

  @override
  String get langNameRu => 'Russian';

  @override
  String get langNamePt => 'Portuguese';

  @override
  String get langNameIt => 'Italian';

  @override
  String get langNameId => 'Indonesian';

  @override
  String get langNameTh => 'Thai';

  @override
  String get langNameVi => 'Vietnamese';

  @override
  String get langNameAr => 'Arabic';

  @override
  String get translateOutgoing =>
      'Translate into their language before sending';

  @override
  String get translateOutgoingTip =>
      'With this on, sending first translates the text into their language — make sure they can read it';

  @override
  String get translateInput => 'Translate the input';

  @override
  String translateOutPreview(String text) {
    return 'Will send: $text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return 'Translated into $lang · tap send to transmit this';
  }

  @override
  String get translateOutCancel => 'Cancel translation';

  @override
  String get translateOutNeedPeer =>
      'Their language is still unknown — set it in the conversation\'s translation settings';

  @override
  String translateSentAs(String text) {
    return 'Sent in their language: $text';
  }

  @override
  String translateTooLongAfter(int n) {
    return 'Translation exceeds the length limit ($n chars) — not sent';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$m/$d/$y $w';
  }

  @override
  String dateWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': 'Mon',
      '2': 'Tue',
      '3': 'Wed',
      '4': 'Thu',
      '5': 'Fri',
      '6': 'Sat',
      '7': 'Sun',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get translate => 'Translate';

  @override
  String get translateText => 'Translate text';

  @override
  String get translateSettings => 'Translation settings';

  @override
  String get translateSettingsSubtitle =>
      'Provider, languages and auto-translate';

  @override
  String get translateProvider => 'Provider';

  @override
  String get translateProviderGoogle => 'Google Translate';

  @override
  String get translateProviderBaidu => 'Baidu Translate';

  @override
  String get translateProviderCustom => 'Custom';

  @override
  String get translateGoogleKey => 'Google API key';

  @override
  String get translateGoogleKeyTip =>
      'API key for Google Cloud Translation v2 — create one in the Google Cloud console';

  @override
  String get translateBaiduAppId => 'Baidu App ID';

  @override
  String get translateBaiduKey => 'Baidu secret key';

  @override
  String get translateBaiduTip =>
      'Apply for general text translation on the Baidu Translate platform; the key stays on this device';

  @override
  String get translateCustomUrl => 'Endpoint URL';

  @override
  String get translateCustomMethod => 'HTTP method';

  @override
  String get translateCustomHeaders => 'Headers (JSON)';

  @override
  String get translateCustomBody => 'Body template';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return 'Placeholders: $text, $from, $to. Ignored when the method is GET';
  }

  @override
  String get translateCustomResultPath => 'Result JSON path';

  @override
  String get translateCustomResultPathTip =>
      'Dot-separated path with array indexes, e.g. data.translations.0.translatedText';

  @override
  String get translateTest => 'Test translation';

  @override
  String translateTestOk(String text) {
    return 'Provider works: $text';
  }

  @override
  String get translateNeedConfig => 'Configure the translation provider first';

  @override
  String translateFailed(String e) {
    return 'Translation failed: $e';
  }

  @override
  String get translateTargetLang => 'Translate into';

  @override
  String get translateSourceLang => 'Source language';

  @override
  String get translateAuto => 'Auto-translate incoming messages';

  @override
  String get translateAutoTip =>
      'Applies to this conversation only; translates received messages only';

  @override
  String get translateShowOriginal => 'Show original';

  @override
  String get translateShowTranslation => 'Show translation';

  @override
  String get translateRetry => 'Translate again';

  @override
  String get translateTranslating => 'Translating…';

  @override
  String get translateCopyOriginal => 'Copy original';

  @override
  String get translateCopyResult => 'Copy translation';

  @override
  String get translateLangAuto => 'Auto detect';

  @override
  String get translateSameLang =>
      'Translation is identical to the original · may need no translation, or the provider failed to translate';

  @override
  String get translateNotNeeded =>
      'Nothing to translate here (numbers / symbols / callsigns)';

  @override
  String translateBubbleCount(int n) {
    return '$n translated';
  }

  @override
  String get translatePrivacyNote =>
      'Translation sends message text to the third-party provider you choose; assess privacy accordingly';

  @override
  String get notifTncConnected => 'TNC connected';

  @override
  String get notifTncDisconnected => 'TNC disconnected';

  @override
  String get dataSourceTitle => 'Data source';

  @override
  String get dataSourceSubtitle => 'Where packets come from';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => 'Global APRS network over the internet';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc =>
      'Send and receive on air through a Bluetooth or serial TNC';

  @override
  String get dataSourceSwitchHint =>
      'Switching the data source disconnects the current link';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL (Kenwood waypoints)';

  @override
  String get dataSourcePkwdwplDesc =>
      'Read the Kenwood \$PKWDWPL waypoint sentences from the radio over Bluetooth or serial (receive-only)';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL is a **receive-only** link: it brings in stations but never transmits (use APRS-IS / TNC / audio for transmitting)';

  @override
  String connConnectingPkwdwpl(String arg) {
    return 'Connecting to PKWDWPL ($arg)…';
  }

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL connected · $arg';
  }

  @override
  String get pkwdwplDeviceTitle => 'PKWDWPL device';

  @override
  String get pkwdwplDeviceDesc =>
      'Bind the radio port and check waypoint reception';

  @override
  String get pkwdwplBindTitle => 'Device binding and status';

  @override
  String get pkwdwplBindSubtitle =>
      'Pick the serial or Bluetooth port that outputs \$PKWDWPL sentences';

  @override
  String get pkwdwplRxOnly => 'Receive-only';

  @override
  String get pkwdwplTip =>
      'Set the PC / GPS port output format on the radio to \"\$PKWDWPL\" (usually 4800 8N1). This link is read-only and transmits nothing.';

  @override
  String get pkwdwplStrictChecksum => 'Strict checksum (drop mismatches)';

  @override
  String get pkwdwplStrictChecksumTip =>
      'Off by default: a mismatch is flagged and logged instead of dropped, because on a local cable it usually means the firmware format differs from the manual. Dropping every sentence would leave the screen empty and make diagnosis much harder.';

  @override
  String get pkwdwplErrReadOnly => 'receive-only link cannot transmit';

  @override
  String get pkwdwplStatTitle => 'Waypoint reception';

  @override
  String pkwdwplStats(String rx) {
    return '$rx waypoints received';
  }

  @override
  String get pkwdwplStatRejected => 'Dropped or invalid sentences';

  @override
  String get pkwdwplStatMismatch => 'Checksum mismatches';

  @override
  String get pkwdwplStatIgnored => 'Other NMEA sentences (ignored)';

  @override
  String get pkwdwplLogEmpty => 'No PKWDWPL log yet';

  @override
  String get tncBindTitle => 'Bluetooth TNC';

  @override
  String get tncBindSubtitle => 'Bind and connect the TNC on your radio';

  @override
  String get tncBoundDevice => 'Bound device';

  @override
  String get tncNotBound => 'No bound device';

  @override
  String get tncScanPaired => 'Scan paired devices';

  @override
  String get tncNoPaired =>
      'No devices found — pair the TNC in the system Bluetooth settings first';

  @override
  String get tncUnbind => 'Unbind';

  @override
  String get tncConnectAction => 'Connect TNC';

  @override
  String get tncRestart => 'Restart link';

  @override
  String get tncSupportedNo =>
      'TNC links are not supported on this platform yet';

  @override
  String get tncNeedPermission =>
      'Bluetooth permission is required — grant it and try again';

  @override
  String get tncOpenFailedHint =>
      'Could not open the device — Windows COM ports are exclusive; make sure no other app holds it';

  @override
  String tncStats(String rx, String tx) {
    return '$rx frames received · $tx sent';
  }

  @override
  String get tncLog => 'Link log';

  @override
  String get tncLogEmpty => 'No log entries yet';

  @override
  String get kissParamsTitle => 'KISS parameters';

  @override
  String get kissParamsSubtitle =>
      'Link-layer settings pushed straight to the TNC';

  @override
  String get kissTxDelay => 'TX delay (ms)';

  @override
  String get kissTxDelayTip =>
      'KISS TXDELAY in 10 ms units — time for your PTT to settle before data';

  @override
  String get kissTxTail => 'TX tail (ms)';

  @override
  String get kissTxTailTip =>
      'KISS TXTAIL in 10 ms units — some radios need the tail to be heard fully';

  @override
  String get kissPersistence => 'Persistence';

  @override
  String get kissPersistenceTip =>
      'KISS PERSISTENCE, 0–255 — lower is more polite and avoids collisions on a shared channel';

  @override
  String get kissSlotTime => 'Slot time (ms)';

  @override
  String get kissSlotTimeTip =>
      'KISS SLOTTIME in 10 ms units — works with persistence to pace channel access';

  @override
  String get kissFullDuplex => 'Full duplex';

  @override
  String get kissFullDuplexTip =>
      'KISS FULLDUPLEX — leave off for ordinary radios (simultaneous TX/RX interferes)';

  @override
  String get kissChannel => 'Channel / KISS port';

  @override
  String get kissChannelTip =>
      'Only multi-channel TNCs have several ports; keep 0 for single-channel radios';

  @override
  String get kissMaxFrame => 'Max frame size (bytes)';

  @override
  String get kissMaxFrameTip =>
      'Longer packets are not sent at all (at 1200 baud an AX.25 frame is ~330 bytes)';

  @override
  String get kissHardwareCmd => 'Vendor command';

  @override
  String get kissHardwareVal => 'Value';

  @override
  String get kissHardwareTip =>
      'KISS SETHARDWARE (0x06), vendor-specific; -1 means do not send';

  @override
  String get kissApplyParams => 'Push parameters';

  @override
  String get kissParamsSent => 'KISS parameters sent';

  @override
  String get kissBackToCommand => 'Return to TNC command mode';

  @override
  String get kissBackToCommandTip =>
      'Sends RETURN (0x0F). Most KISS TNCs stop forwarding until the link is restarted';

  @override
  String get kissRfPath => 'RF digipeater path';

  @override
  String get kissRfPathTip =>
      'Digipeaters used on air, e.g. WIDE1-1,WIDE2-1; leave empty for none';

  @override
  String get kissRfBeacon => 'Allow RF beaconing';

  @override
  String get kissRfBeaconTip =>
      'Only then will positions be transmitted on air. Transmitting requires your own licence and callsign';

  @override
  String get kissAutoAck => 'Auto-acknowledge';

  @override
  String get kissAutoAckTip =>
      'When off, incoming messages are not acknowledged — keeps the channel quieter';

  @override
  String get kissAutoReconnect => 'Reconnect automatically';

  @override
  String get kissNeedConnected => 'Connect the TNC first';

  @override
  String get tncSwitchOn => 'On';

  @override
  String get tncSwitchOff => 'Off';

  @override
  String get connTncSourceHint =>
      'TNC mode does not use a server or filters, so those settings are disabled';

  @override
  String get connectTncBar => 'Tap Connect to open the TNC link';

  @override
  String connectingToTnc(String name) {
    return 'Connecting TNC · $name';
  }

  @override
  String get tncMsgTitle => 'Radio (TNC) mode';

  @override
  String get tncMsgDesc =>
      'The radio channel is shared, so messaging is limited accordingly';

  @override
  String get tncGroupDisabled =>
      'Group broadcasts are unavailable in radio mode';

  @override
  String tncMsgLimitHint(String n) {
    return '$n characters per message (APRS spec)';
  }

  @override
  String get tncMsgTooLong => 'Exceeds the message length limit for radio mode';

  @override
  String get licenseSection => 'License';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      'This software is released under the GNU GPL v3. You may run, study, modify, and redistribute it under the terms of the license; modified and redistributed versions must comply with the applicable GPL v3 requirements. This software is provided without warranty.';

  @override
  String get licenseText => 'View license';

  @override
  String get oobeAgreeTitle => 'User Agreement & License';

  @override
  String get oobeAgreeBody =>
      'Welcome to APRSlocus! Please read and agree to the terms below before using the app. Note that APRS data is public: once sent, it may be received, stored and forwarded by the global APRS network.';

  @override
  String get oobeAgreeCheck =>
      'I have read and agree to the User Agreement and the GPL-3.0 license';

  @override
  String get oobeAgreeNeed =>
      'Please read and agree to the User Agreement first';

  @override
  String get oobeDeclineExit => 'Decline and exit';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get beaconWarnTitle => 'Beacon interval too short';

  @override
  String get beaconWarnBody =>
      'APRS-IS recommends a minimum 60-second beacon interval for mobile stations. Sending faster may be considered abuse and could lead to disconnection. Keep this interval anyway?';

  @override
  String get beaconWarnKeep => 'Keep anyway';

  @override
  String get beaconWarnFix => 'Set to 60 s';

  @override
  String get features => 'Features';

  @override
  String get openSource => 'Open-source acknowledgements';

  @override
  String get feedback => 'Feedback';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get qqGroup => 'QQ group';

  @override
  String get projectRepo => 'Repository';

  @override
  String get testMembers => 'Test members';

  @override
  String get aiSupport => 'AI compute support';

  @override
  String get copyAppInfo => 'Copy app info';

  @override
  String get appInfoCopied => 'App info copied';

  @override
  String get shareApp => 'Share APRSlocus';

  @override
  String get shareToSystem => 'Share to system';

  @override
  String get shareToSystemDesc => 'WeChat, QQ, SMS, etc.';

  @override
  String get copyShareText => 'Copy share text';

  @override
  String get openDownload => 'Open download page';

  @override
  String get shareTextCopied => 'Share text copied, paste it to your friends';

  @override
  String get shareText =>
      'APRSlocus — APRS Tracking & Mapping for amateur radio 📡\nReal-time station tracking, messaging & beaconing. Available on Android & Windows.\nWebsite: https://aprslocus.theez.top/\nDownload: https://github.com/dariondong/APRSLocus/releases';

  @override
  String get enterCallsign => 'Please enter your callsign';

  @override
  String get enterValidCall => 'Please enter a valid callsign';

  @override
  String get stationSettings2 => 'Station settings';

  @override
  String get beaconSettings => 'Beaconing';

  @override
  String get displaySettings2 => 'Display settings';

  @override
  String get chatSettings2 => 'Chat settings';

  @override
  String get dataSettings2 => 'Data settings';

  @override
  String get advancedSettings2 => 'Advanced settings';

  @override
  String get connectionSettings2 => 'Connection settings';

  @override
  String get myCallsign => 'My callsign';

  @override
  String get beaconEnabled => 'Enable beaconing';

  @override
  String get smartBeacon => 'SmartBeacon (by speed)';

  @override
  String get packetConsole => 'Packet console';

  @override
  String get rawMode => 'Raw mode';

  @override
  String get parsedMode => 'Parsed mode';

  @override
  String get position => 'Position';

  @override
  String get statusType => 'Status';

  @override
  String get objectType => 'Object';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return 'RX $rx · TX $tx · $ppm/min';
  }

  @override
  String get searchPacket => 'Search callsign, dest or raw…';

  @override
  String get noMatchingPackets => 'No matching packets';

  @override
  String get inject => 'Inject';

  @override
  String get manualInject => 'Inject raw APRS packet';

  @override
  String get injected => 'Packet injected';

  @override
  String get clearedPackets => 'Packets cleared';

  @override
  String get clearPackets => 'Clear packets';

  @override
  String noPositionInfo(Object call) {
    return 'No position information for $call (packet contains no position)';
  }

  @override
  String get copiedPacket => 'Packet copied';

  @override
  String get mapPickMode => 'Map position picker';

  @override
  String get mapPickDesc => 'Tap the map to set your position';

  @override
  String foundStations(Object count, Object q) {
    return 'Found $count stations matching \"$q\"';
  }

  @override
  String get tapMapHint => 'Tap map for stations · pinch to zoom';

  @override
  String myLocationPanel(Object call) {
    return 'My location · $call';
  }

  @override
  String get speedLabel => 'Speed';

  @override
  String get courseLabel => 'Course';

  @override
  String get telemetryTitle => 'Speed / Altitude';

  @override
  String get range10m => '10 min';

  @override
  String get range30m => '30 min';

  @override
  String get range1h => '1 h';

  @override
  String get range3h => '3 h';

  @override
  String get rangeAll => 'All';

  @override
  String get beaconIntervalLabel => 'Interval';

  @override
  String get beaconsSentLabel => 'Sent';

  @override
  String get nextBeaconLabel => 'Next';

  @override
  String positionBeacon(Object grid) {
    return 'Position beacon · Grid $grid';
  }

  @override
  String get manualBeacon => 'Beacon now';

  @override
  String get mapPickNow => 'Pick on map';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return 'Position set · $lat, $lng · Grid $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count online';
  }

  @override
  String movingCount(Object count) {
    return '$count moving';
  }

  @override
  String stationCount(Object count) {
    return '$count stations';
  }

  @override
  String get locateMe => 'Locate';

  @override
  String get layerFilter => 'Layers';

  @override
  String get showAll => 'Show all';

  @override
  String get otherType => 'Other';

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
  String get noStationInView => 'No stations here · tap to show all';

  @override
  String get noStationHelp => 'No stations here · tap for help';

  @override
  String get mapHelpTitle => 'Map help';

  @override
  String get mapHelpIntro =>
      'No stations in view. Possible reasons: not connected to APRS-IS, small receive range, or no active stations nearby.';

  @override
  String get mapHelpMove =>
      'Move / zoom: drag to pan, pinch or scroll-wheel to zoom';

  @override
  String get mapHelpStation =>
      'Stations: tap a marker to select & center, double-tap for details';

  @override
  String get mapHelpLayer =>
      'Layers & style: top-right buttons filter station types / switch basemap';

  @override
  String get mapHelpLocate =>
      'Locate: tap “Locate me” (bottom-right) to return to your position';

  @override
  String get mapHelpSearch =>
      'Search: type a callsign in the top search box to jump to it';

  @override
  String get allChangelog => 'All changelogs';

  @override
  String get tapToView => 'Tap to view';

  @override
  String get beaconNow => 'Beacon now';

  @override
  String get meLabel => 'Me';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get mapHome => 'Recenter';

  @override
  String get mapLocate => 'Locate';

  @override
  String get mapLayers => 'Layers';

  @override
  String get featureLiveMap => 'AMap';

  @override
  String get featureLiveMapDesc =>
      'GCJ-02 coordinates with smooth zooming and panning';

  @override
  String get featureGps => 'GPS positioning';

  @override
  String get featureGpsDesc =>
      'Native Android location, no Google services required';

  @override
  String get featureBeacon => 'Beaconing';

  @override
  String get featureBeaconDesc =>
      'Custom content, rate, and symbol with APRS-standard formatting';

  @override
  String get featureMsg => 'Messages';

  @override
  String get featureMsgDesc =>
      'Feed + conversation views with Unicode text and auto-reply support';

  @override
  String get featureAutoConnect => 'Auto-connect';

  @override
  String get featureAutoConnectDesc =>
      'Automatically connects to a public server and stays online in the background';

  @override
  String get featureLayerFilter => 'Layer filter';

  @override
  String get featureLayerFilterDesc =>
      'Filter: mobile, fixed, digipeater, weather, FMO';

  @override
  String get featureFmo => 'FMO stations';

  @override
  String get featureFmoDesc =>
      'Automatically detects FMO data and shows structured details';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Google cross-platform UI framework';

  @override
  String get osAmap => 'AMap';

  @override
  String get osAmapDesc => 'Map tile service';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => 'Global APRS data network';

  @override
  String get osHam => 'Amateur radio';

  @override
  String get osHamDesc => 'Contributions from the APRS amateur radio community';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => 'Callsign';

  @override
  String get website => 'Website';

  @override
  String get sponsorAuthor => 'Author BG7LZQ';

  @override
  String get sponsorAuthorItems =>
      'Develops and maintains this project in spare time';

  @override
  String get sponsorGroup => 'STUDENT HAMS';

  @override
  String get sponsorGroupItems => 'Thanks to the group for financial support';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => 'Thanks for sponsoring a Mixue drink 🧋';

  @override
  String get sponsorEvery => 'Every supporter';

  @override
  String get sponsorEveryItems =>
      'Every contribution helps keep the project going';

  @override
  String get donateWechat => 'WeChat donation';

  @override
  String get donateWechatDesc =>
      'Long-press to save the QR code · tap to enlarge';

  @override
  String get donateAlipay => 'Alipay donation';

  @override
  String get donateAlipayDesc => 'Contact the author for the donation QR code';

  @override
  String get nonprofitNote =>
      'Non-profit learning and community project\nDonations only cover server and development costs';

  @override
  String get myStation => 'My station';

  @override
  String get callSsid => 'Callsign · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc =>
      'SSID is a callsign suffix for devices, e.g. -9 in BG7ABC-9';

  @override
  String get callComment => 'Station comment';

  @override
  String get callCommentHint => 'Comment sent with position beacons';

  @override
  String get callSymbol => 'Station symbol';

  @override
  String get callSymbolDesc => 'Symbol sent with position beacons';

  @override
  String get autoReply => 'Auto-reply';

  @override
  String get sendBeacon => 'Send beacon';

  @override
  String get mapTypeDesc =>
      '\"Map 2.0 (vector)\" renders vectors on-device for lower data use and sharp zooming; AMap raster/satellite uses online tiles.';

  @override
  String get msgHistory => 'Message history';

  @override
  String get statistics => 'Statistics';

  @override
  String get clearData => 'Clear data';

  @override
  String get favorites => 'Favorites / Manual';

  @override
  String get favoriteStations => 'Favorite stations';

  @override
  String get manualStations => 'Manual stations';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get onlyWgs84 => 'WGS-84 only';

  @override
  String get contactList => 'Contacts';

  @override
  String get contactDesc => 'Message/contact filtering rules';

  @override
  String get dataClearDesc =>
      'Clear local messages, packets, stations, and other data';

  @override
  String get advancedDesc => 'Lab & developer tools';

  @override
  String get labDesc =>
      'Lab features are experimental and may affect usability. Portrait orientation is locked by default; enable this to allow landscape.';

  @override
  String get systemLog => 'System log';

  @override
  String get devDesc => 'Developer tools';

  @override
  String get simData => 'Enable demo data (sample stations/packets)';

  @override
  String get rxTx => 'RX / TX';

  @override
  String get stationCount2 => 'Stations';

  @override
  String get appInfo => 'App info';

  @override
  String get clearMessages => 'Clear all chat history';

  @override
  String get clearPackets2 => 'Clear packets';

  @override
  String get clearStations => 'Clear station list';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get resetAll => 'Reset all settings';

  @override
  String get resetAllDesc => 'Factory reset';

  @override
  String get dataPersistence => 'Station persistence';

  @override
  String get autoSaveStations => 'Save station data automatically';

  @override
  String get gridFormat => 'Grid format';

  @override
  String get coordsFormat => 'Coord format';

  @override
  String get appVersion => 'Version';

  @override
  String get appVersionDesc => 'Current app version';

  @override
  String get stationDetail => 'Station detail';

  @override
  String get backToTop => 'Back to top';

  @override
  String get installApk => 'Install APRSlocus';

  @override
  String get install => 'Install';

  @override
  String get cancelInstall => 'Cancel';

  @override
  String get openFolder => 'Open folder';

  @override
  String get browse => 'Browse';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get downloadNow => 'Download now';

  @override
  String get downloading => 'Downloading';

  @override
  String downloadProgress(Object p) {
    return 'Downloading $p%';
  }

  @override
  String get downloadComplete => 'Download complete';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get installNow => 'Install now';

  @override
  String get installComplete => 'Install complete';

  @override
  String get openInstallDir => 'Open install folder';

  @override
  String get deletePackage => 'Delete package';

  @override
  String deletePackageConfirm(Object file) {
    return 'Delete package $file?';
  }

  @override
  String get deleteAllPackages => 'Delete all packages';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return 'Delete all packages ($count)';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return 'Delete $count downloaded packages ($size)? This cannot be undone.';
  }

  @override
  String get historyVersions => 'History';

  @override
  String get current => 'Current';

  @override
  String get newVersion => 'New version';

  @override
  String get latestVersion => 'You are up to date';

  @override
  String get currentVersion => 'Current APRSlocus version';

  @override
  String get checking => 'Checking for updates…';

  @override
  String get checkingGitCode => 'Checking GitCode repository';

  @override
  String get updateFailed => 'Update check failed';

  @override
  String get noUpdateFound => 'You are up to date';

  @override
  String get newVersionFound => 'New version available';

  @override
  String get downloadAgain => 'Download package again';

  @override
  String get openDownloads => 'Open downloads folder';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String currentVsRepo(Object local, Object remote) {
    return 'Installed v$local · Latest v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return '$os package size: $size';
  }

  @override
  String get alreadyDownloaded => 'Package downloaded';

  @override
  String get downloadReady => 'Download installation package';

  @override
  String get appInstallDir => 'Install folder';

  @override
  String get runInstaller => 'Run installer';

  @override
  String get downloadUpdateTip => 'Download the update and open it';

  @override
  String get openDownloadFolder => 'Open downloads folder';

  @override
  String groupBubble(String name) {
    return 'Group · $name';
  }

  @override
  String get groupInviteTitle => 'Group chat invitation';

  @override
  String groupInviteFrom(String from) {
    return '$from invited you to a group chat';
  }

  @override
  String groupNameValue(String name) {
    return 'Group: $name';
  }

  @override
  String groupCallsignValue(String call) {
    return 'Group callsign: $call';
  }

  @override
  String groupInviteAccepted(String name) {
    return 'Joined $name';
  }

  @override
  String get accept => 'Accept';

  @override
  String groupInviteRejected(String name) {
    return 'Declined invitation to $name';
  }

  @override
  String get reject => 'Decline';

  @override
  String get appTagline => 'APRS tracking';

  @override
  String gridValue(String grid) {
    return 'Grid $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/min';
  }

  @override
  String get demo => 'Demo';

  @override
  String nextBeaconIn(String time) {
    return 'Next beacon $time';
  }

  @override
  String beaconCount(int count) {
    return 'Beacons $count';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return 'Position beacon sent · Grid $grid · Sent to APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return 'Position beacon sent · Grid $grid · Demo';
  }

  @override
  String get getLocation => 'Get location';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connectAprsIs => 'Connect APRS-IS';

  @override
  String get packetsReceived => 'RX';

  @override
  String get passcodeUnverified => 'Passcode not verified';

  @override
  String get passcodeWarning =>
      'The login passcode may be incorrect; messages may not work';

  @override
  String get goSettings => 'Settings';

  @override
  String get connectingServer => 'Connecting to server…';

  @override
  String get notConnectedAprsServer => 'Not connected to APRS-IS';

  @override
  String connectingToServer(String server, int port) {
    return 'Connecting to $server:$port…';
  }

  @override
  String get connectNearbyDesc =>
      'Connect to receive nearby station positions and messages';

  @override
  String get connectAction => 'Connect';

  @override
  String get backgroundRunTip =>
      'Background operation: allow APRSlocus to run in the background, disable battery optimization, and allow autostart to keep beaconing active.';

  @override
  String get connectedAprsIs => 'Connected to APRS-IS';

  @override
  String get qqGroupDesc => 'APRSlocus · Feedback and discussion';

  @override
  String get reselectPoint => 'Pick again';

  @override
  String get disableClustering => 'Disable clustering';

  @override
  String get enableClustering => 'Enable clustering';

  @override
  String get heatmap => 'Station heatmap';

  @override
  String get heatmapHint => 'Show station density heatmap when zoomed out';

  @override
  String get groupTracking => 'Group tracking';

  @override
  String get groupTrackingHint =>
      'Group callsigns you care about and track them on a big map (caravan / friends). Landscape friendly.';

  @override
  String get newTrackGroup => 'New track group';

  @override
  String get trackGroupNameHint => 'Name, e.g. Weekend Ride';

  @override
  String get editTrackGroup => 'Edit track group';

  @override
  String get deleteTrackGroup => 'Delete track group';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return 'Delete track group “$name”?';
  }

  @override
  String get pickTrackMembers => 'Pick members (check callsigns to track)';

  @override
  String get saveAndTrack => 'Save & track';

  @override
  String get trackGroupsEmptyHint =>
      'No track groups yet. Tap “New track group” to create one.';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty =>
      'Members have no position data yet (not received or not beaconing).';

  @override
  String get trackActive => 'Active';

  @override
  String get trackWaitingPos => 'Waiting for position…';

  @override
  String get offlineShort => 'Offline';

  @override
  String get stoppedShort => 'Stopped';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total members · $online online · $fixed fixed';
  }

  @override
  String get groupChatShort => 'Chat';

  @override
  String groupChatTitle(Object name) {
    return 'Group · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return 'Chat with $call';
  }

  @override
  String get chatToGroupHint => 'Message the group…';

  @override
  String chatToHint(Object call) {
    return 'Message $call…';
  }

  @override
  String get noMessagesHint => 'No messages yet — say hi!';

  @override
  String trackModeFollow(Object call) {
    return 'Following $call';
  }

  @override
  String get trackModeMe => 'Following me';

  @override
  String get trackModeFitAll => 'Keep-fit all';

  @override
  String get fitAll => 'Fit all';

  @override
  String get noStationsYet =>
      'No station data yet. Connect to APRS-IS to pick members.';

  @override
  String get noPackets => 'No packets yet';

  @override
  String secondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String copiedCoordsValue(String coords) {
    return 'Coordinates copied: $coords';
  }

  @override
  String copiedGridValue(String grid) {
    return 'Grid copied: $grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return '$distance km away · Bearing $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return 'Weather · $data';
  }

  @override
  String get symbolLabel => 'Symbol';

  @override
  String get digipeaterTapHint =>
      'Tap a digipeater to open its station details';

  @override
  String get copiedFmoInfo => 'FMO info copied';

  @override
  String get copiedAprslocusInfo => 'APRSlocus info copied';

  @override
  String trackPoints(int count) {
    return 'Track ($count points)';
  }

  @override
  String sendMessageTo(String call) {
    return 'Message $call…';
  }

  @override
  String get navigationUnavailable =>
      'AMap is not installed and no other map app could be opened';

  @override
  String stationNoData(String call) {
    return 'No data received from $call yet';
  }

  @override
  String get software => 'Software';

  @override
  String get close => 'Close';

  @override
  String get nameLabel => 'Name';

  @override
  String get viewSponsorDetails => 'View author and sponsor details →';

  @override
  String get thanks => 'Thanks';

  @override
  String get qqSoftwareName => 'APRSlocus';

  @override
  String get usageNotice =>
      'For amateur-radio learning and communication only\nFollow your local radio regulations';

  @override
  String get licenseNotice => 'GNU GPL v3 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\nAuthor: BG7LZQ (Darion)\nWebsite: Theez.top';
  }

  @override
  String get eggBg7lzq => 'Hey, what are you doing~';

  @override
  String get eggBg7pgw => 'Seriously?';

  @override
  String get eggBg7lmw => 'Quiet as ever...';

  @override
  String get eggBg7osl => 'You have got some nerve';

  @override
  String get manualCallsignHint => 'Enter callsign manually';

  @override
  String get noPacketReceived => 'No packets received';

  @override
  String get feedMode => 'Feed';

  @override
  String get conversationMode => 'Chats';

  @override
  String get messageFeed => 'Message feed';

  @override
  String messageTotal(int count) {
    return '$count messages';
  }

  @override
  String get noMessages => 'No messages yet';

  @override
  String get copiedClipboard => 'Copied to clipboard';

  @override
  String get groupShortLabel => 'Group';

  @override
  String get conversations => 'Chats';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get groupNotFound => 'Group chat not found';

  @override
  String get invite => 'Invite';

  @override
  String get manage => 'Manage';

  @override
  String get noGroupMessages => 'No group messages yet';

  @override
  String get selectConversation => 'Select a conversation to start chatting';

  @override
  String get newConversation => 'New conversation';

  @override
  String get newConversationDesc => 'Enter a callsign to start a conversation';

  @override
  String get callsignExample => 'Callsign, e.g. BG7ABC';

  @override
  String get start => 'Start';

  @override
  String get broadcastMessage => 'Broadcast message';

  @override
  String get noStations => 'No stations';

  @override
  String get broadcastHint =>
      'Each message is sent separately to every recipient';

  @override
  String broadcastSent(int count) {
    return 'Sent to $count recipients';
  }

  @override
  String get searchCallsign => 'Search callsign…';

  @override
  String get broadcastContentHint => 'Enter message to broadcast…';

  @override
  String get groupNameHint => 'Enter group name';

  @override
  String get create => 'Create';

  @override
  String groupCallsignLine(String call) {
    return 'Group callsign: $call';
  }

  @override
  String get noMembers => 'No members';

  @override
  String get inviteMembersHint => 'Tap “Invite members” below to add people';

  @override
  String get remove => 'Remove';

  @override
  String get inviteMembers => 'Invite members';

  @override
  String get deleteGroup => 'Delete group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get deleteConversation => 'Delete chat';

  @override
  String deleteConversationConfirm(Object call) {
    return 'Delete the chat history with $call? The conversation will also be removed from the list. This cannot be undone.';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return 'Clear the chat history of “$name”? This cannot be undone.';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members members · $online online';
  }

  @override
  String get leaveGroup => 'Leave group';

  @override
  String leaveGroupConfirm(String name) {
    return 'Leave “$name”? You will stop receiving messages from this group.';
  }

  @override
  String leftGroup(String name) {
    return 'Left $name';
  }

  @override
  String get leave => 'Leave';

  @override
  String inviteMembersTo(String name) {
    return 'Invite members to $name';
  }

  @override
  String get manualCallsign => 'Enter callsign manually';

  @override
  String inviteSent(String call) {
    return 'Invitation sent to $call';
  }

  @override
  String get noMoreOnlineStations => 'No more online stations';

  @override
  String get invited => 'Invited';

  @override
  String get tapToInvite => 'Tap to invite';

  @override
  String get done => 'Done';

  @override
  String get addContact => 'Add contact';

  @override
  String get addContactDesc => 'Enter a callsign to add it to contacts';

  @override
  String contactAdded(String call) {
    return 'Added contact $call';
  }

  @override
  String get add => 'Add';

  @override
  String get stationary => 'Stationary';

  @override
  String get unknown => 'Unknown';

  @override
  String get none => 'None';

  @override
  String get manual => 'Manual';

  @override
  String get management => 'Manage';

  @override
  String get debugLabel => 'Debug';

  @override
  String get information => 'Info';

  @override
  String get warning => 'Warning';

  @override
  String get errorLabel => 'Error';

  @override
  String countTimes(int count) {
    return '$count times';
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
      'car': 'Car',
      'police': 'Police',
      'person': 'Person',
      'digitalRepeater': 'Digipeater',
      'telephone': 'Telephone',
      'dxCluster': 'DX cluster',
      'hfGateway': 'HF gateway',
      'smallAircraft': 'Small aircraft',
      'mobileSatellite': 'Mobile satellite',
      'disabled': 'Accessibility',
      'snowmobile': 'Snowmobile',
      'redCross': 'Red Cross',
      'scouts': 'Scouts',
      'house': 'House',
      'redX': 'Red X',
      'redDot': 'Red dot',
      'fire': 'Fire',
      'campground': 'Campground',
      'motorcycle': 'Motorcycle',
      'train': 'Train',
      'fileServer': 'File server',
      'hurricane': 'Hurricane',
      'dfTriangle': 'DF triangle',
      'postOffice': 'Post office',
      'largeAircraft': 'Large aircraft',
      'weatherStation': 'Weather station',
      'satelliteDish': 'Satellite dish',
      'ambulance': 'Ambulance',
      'bicycle': 'Bicycle',
      'commandPost': 'Command post',
      'fireStation': 'Fire station',
      'horse': 'Horse',
      'fireTruck': 'Fire truck',
      'glider': 'Glider',
      'hospital': 'Hospital',
      'fmoStation': 'FMO station',
      'jeep': 'Jeep',
      'truck': 'Truck',
      'laptop': 'Laptop',
      'micERepeater': 'Mic-E digipeater',
      'node': 'Node',
      'emergencyOps': 'Emergency operations',
      'dog': 'Dog',
      'gridSquare': 'Grid square',
      'repeaterTower': 'Repeater tower',
      'boat': 'Boat',
      'truckStop': 'Truck stop',
      'semiTrailer': 'Semi-trailer',
      'van': 'Van',
      'waterStation': 'Water station',
      'yagi': 'Yagi antenna',
      'shelter': 'Shelter',
      'rv': 'RV',
      'weatherSymbol': 'Weather station',
      'balloon': 'Balloon',
      'bus': 'Bus',
      'shuttle': 'Space shuttle',
      'policeCar': 'Police car',
      'sailboat': 'Sailboat',
      'school': 'School',
      'lodging': 'Lodging',
      'hotel': 'Hotel',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': 'Vehicles / transport',
      'facilities': 'Buildings / facilities',
      'weatherNature': 'Weather / nature',
      'emergencyRescue': 'Emergency / rescue',
      'airWater': 'Air / water',
      'communications': 'Communications / other',
      'other': 'Other',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': 'China',
      'KR': 'South Korea',
      'JP': 'Japan',
      'US': 'United States',
      'CA': 'Canada',
      'GB': 'United Kingdom',
      'DE': 'Germany',
      'FR': 'France',
      'IT': 'Italy',
      'ES': 'Spain',
      'RU': 'Russia',
      'AU': 'Australia',
      'NZ': 'New Zealand',
      'BR': 'Brazil',
      'AR': 'Argentina',
      'MX': 'Mexico',
      'ZA': 'South Africa',
      'IN': 'India',
      'TH': 'Thailand',
      'SG': 'Singapore',
      'MY': 'Malaysia',
      'ID': 'Indonesia',
      'PH': 'Philippines',
      'TW': 'Taiwan',
      'HK': 'Hong Kong',
      'MO': 'Macao',
      'other': 'Unknown',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => 'Not located';

  @override
  String get simulatedLocation => 'Simulated location';

  @override
  String get savedLocation => 'Saved location';

  @override
  String get locationFailed => 'Location failed';

  @override
  String get locationStopped => 'Location stopped';

  @override
  String get locationFixed => 'Location acquired';

  @override
  String get locationPermission => 'Grant location permission…';

  @override
  String get gpsLocating => 'Acquiring GPS location…';

  @override
  String get webLocationUnsupported =>
      'Automatic location is unavailable on the web; enter coordinates manually';

  @override
  String locationStreamError(String error) {
    return 'Location stream error: $error';
  }

  @override
  String locationInitError(String error) {
    return 'Location initialization failed: $error';
  }

  @override
  String get beaconDisabled => 'Disabled';

  @override
  String get waitingForLocation => 'Waiting for location';

  @override
  String get imminent => 'Soon';

  @override
  String get connTapToConnect => 'Not connected · Tap connect to join APRS-IS';

  @override
  String get connManuallyDisconnected =>
      'Not connected · Manually disconnected';

  @override
  String connAutoReconnect(int seconds) {
    return 'Connection lost · Reconnecting in ${seconds}s…';
  }

  @override
  String connConnectingTarget(String target) {
    return 'Connecting to $target…';
  }

  @override
  String connOnline(String call) {
    return 'Connected · $call online';
  }

  @override
  String connRetry(int seconds) {
    return 'Connection failed · Retrying in ${seconds}s…';
  }

  @override
  String connPositionSent(String call) {
    return 'Connected · Position beacon sent ($call)';
  }

  @override
  String get connDemoBeacon =>
      'Not connected · Position beacon recorded (demo)';

  @override
  String get connPasscodeInvalid =>
      'Connected · Unverified (Passcode may be incorrect)';

  @override
  String get mapTypeAmap => 'AMap';

  @override
  String get mapTypeAmapSatellite => 'AMap Satellite';

  @override
  String get mapTypeVector => 'Vector map';

  @override
  String get amapGroup => 'AMap';

  @override
  String get domesticMaps => 'China maps';

  @override
  String get internationalMaps => 'Global maps';

  @override
  String get metricUnits => 'Metric (km/h, m)';

  @override
  String get coordDisplay => 'Coordinate display';

  @override
  String mapDefaultCoord(int level) {
    return 'Beijing · Zoom $level';
  }

  @override
  String secondsValue(int count) {
    return '$count sec';
  }

  @override
  String get stationSettingsDetail => 'Callsign, SSID, symbol & comment';

  @override
  String get stationIdentity => 'Station identity';

  @override
  String get aprsCallsignHint => 'APRS callsign, e.g. BV2AAA';

  @override
  String get displayInfo => 'Station info';

  @override
  String get ssidSuffix => 'SSID suffix';

  @override
  String get chooseSsidSuffix => 'Choose SSID suffix';

  @override
  String get mySymbol => 'My symbol';

  @override
  String get moreSymbols => 'More symbols';

  @override
  String get allAprsSymbols => 'All APRS symbols';

  @override
  String get beaconSettingsDetail => 'GPS source, beaconing & manual location';

  @override
  String get locationSource => 'Location source';

  @override
  String get useDeviceLocation => 'Use device location';

  @override
  String get manualCoordinates => 'Enter coordinates manually';

  @override
  String get locationMode => 'Location mode';

  @override
  String get settingsLocModeSubtitle => 'Choose location method';

  @override
  String get locModeGps => 'GPS only';

  @override
  String get locModeGpsDesc => 'Satellite only, saves battery';

  @override
  String get locModeGpsNetwork => 'GPS + Network';

  @override
  String get locModeGpsNetworkDesc => 'Network-assisted, faster fix';

  @override
  String get beaconingSection => 'Beaconing';

  @override
  String get beaconIntervalTip => 'Position beacon interval, minimum 5 seconds';

  @override
  String get beaconContent => 'Beacon contents';

  @override
  String get beaconContentDesc => 'Sent with each position beacon';

  @override
  String get phoneBattery => 'Phone battery';

  @override
  String get locationStatus => 'Location status';

  @override
  String get relocate => 'Relocate';

  @override
  String get startGps => 'Start GPS';

  @override
  String get trackingBeaconing =>
      'Location is active and position beacons are being sent';

  @override
  String get manualLocation => 'Manual location';

  @override
  String get latitudeHint => 'Latitude 39.9042';

  @override
  String get longitudeHint => 'Longitude 116.4074';

  @override
  String get invalidLatLng => 'Enter valid latitude and longitude';

  @override
  String myLocationSetGrid(String grid) {
    return 'Location set · Grid $grid';
  }

  @override
  String get applyCoordinates => 'Apply coordinates';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get manualLocationHelp =>
      'If automatic location is unavailable, enter coordinates or pick a point on the map for beaconing and distance calculations.';

  @override
  String get passcodeTip =>
      'APRS-IS login passcode; generate it online. Use -1 for unverified login';

  @override
  String get websocketOptional => 'WebSocket URL (optional)';

  @override
  String get configChanged => 'Configuration changed';

  @override
  String get reconnectToApply => 'Reconnect to apply';

  @override
  String get reconnected => 'Reconnected';

  @override
  String get connectFailedCheckConfig =>
      'Connection failed; check the configuration';

  @override
  String get rangeFilterDesc =>
      'Receive only station packets within the configured range';

  @override
  String get filterCenterFollows => 'Follow my location for filter center';

  @override
  String get radiusTip =>
      'Receive radius (km); tap “Save & apply filter” to apply';

  @override
  String get maxStationsTip =>
      'Maximum stations kept in memory (unlimited by default; increase as needed)';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · Radius $radius km';
  }

  @override
  String get receiveFilterDesc2 =>
      'In addition to the range filter, receive stations by country/region or exact callsign';

  @override
  String get receiveCountryDesc =>
      'Receive all stations from a country/region by callsign prefix';

  @override
  String get noCountriesSelected => 'No countries or regions selected';

  @override
  String get receiveOthersDesc =>
      'Receive special stations whose callsigns do not match selected countries';

  @override
  String get addCountry => 'Add country/region';

  @override
  String get chatSettingsDetail => 'Messages, contacts & chat data';

  @override
  String get messageCountLabel => 'Messages';

  @override
  String get manageContacts => 'Manage contacts';

  @override
  String deleteAllChatsConfirm(int count) {
    return 'Delete all $count chat messages? This cannot be undone.';
  }

  @override
  String get chatCleared => 'Chat history cleared';

  @override
  String get noContacts => 'No contacts';

  @override
  String get addOrFavoriteContact =>
      'Tap “Add” above or favorite a station on the map';

  @override
  String movingWithSpeed(String speed) {
    return 'Moving · $speed';
  }

  @override
  String get callsignMin3 => 'Callsign must be at least 3 characters';

  @override
  String get deleteContact => 'Delete contact';

  @override
  String deleteContactConfirm(String call) {
    return 'Delete contact $call?';
  }

  @override
  String contactDeleted(String call) {
    return 'Deleted $call';
  }

  @override
  String get dataMaintenance => 'Data maintenance';

  @override
  String get clearAllData => 'Clear all data';

  @override
  String get clearAllDataIntro => 'This will delete all local data below:';

  @override
  String get chatHistory => 'Chat history';

  @override
  String get logs => 'Logs';

  @override
  String get irreversibleKeepSettings =>
      'This cannot be undone. Connection settings and callsign will be kept.';

  @override
  String get confirmClearAllData => 'Clear all data';

  @override
  String get clearAllDataConfirm =>
      'Clear all local data? This cannot be undone.';

  @override
  String get allDataCleared => 'All local data cleared';

  @override
  String get confirmClear => 'Clear';

  @override
  String get allowLandscape => 'Allow landscape orientation';

  @override
  String get packetParseTest => 'Packet parser test';

  @override
  String get packetParseHint =>
      'Paste a raw APRS packet, e.g.:\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test station';

  @override
  String get parseAndApply => 'Parse & apply';

  @override
  String get oobePasscodeMissing => 'Passcode not entered';

  @override
  String get oobePasscodeMissingDesc =>
      'The Passcode is the APRS-IS login verification code for your callsign.\n\nThe default -1 allows an unverified connection, but messages and group chat will not work normally.\n\nLook up the correct Passcode for your callsign at https://aprs.cool/AprsPG.';

  @override
  String get continueAnyway => 'Continue anyway';

  @override
  String get fillPasscode => 'Enter Passcode';

  @override
  String get oobeMapFeatureDesc =>
      'AMap tiles with nearby APRS stations and tracks';

  @override
  String get oobeGpsFeatureDesc =>
      'Acquire your location and send position beacons to APRS-IS';

  @override
  String get oobeMsgFeatureDesc =>
      'Exchange station messages with auto-reply support';

  @override
  String get oobeIsFeatureDesc =>
      'Connect to a public server and receive global APRS station data';

  @override
  String get oobeBackgroundTip =>
      'Tip: allow APRSlocus to run in the background, disable battery optimization, and allow autostart to keep beaconing active.';

  @override
  String get oobeNextSteps =>
      'Complete the basic setup in the next few steps. You can change it later in Settings.';

  @override
  String get ssidDescShort =>
      'SSID is the numeric callsign suffix, such as -9 in BG7ABC-9';

  @override
  String get ssidOptional => 'SSID suffix (optional)';

  @override
  String get noSsid => 'No suffix (base callsign)';

  @override
  String fullCallsign(String call) {
    return 'Full callsign: $call';
  }

  @override
  String get passcodeImportant => 'Passcode is important';

  @override
  String get passcodeImportantDesc =>
      'A correct Passcode is required to receive group messages and send acknowledgements. -1 can connect, but messaging will not work normally.';

  @override
  String get lookupPasscode => 'Look up your Passcode →';

  @override
  String get passcodeLookupHint => 'Enter your callsign, e.g. BV2AAA';

  @override
  String sendToGroupHint(String group) {
    return 'Send to $group…';
  }

  @override
  String sendToCallHint(String call) {
    return 'Send to $call…';
  }

  @override
  String get selectMessageReply => 'Select a message to reply…';

  @override
  String get broadcastShort => 'Broadcast';

  @override
  String memberCount(int count) {
    return '$count members';
  }

  @override
  String memberCountTap(int count) {
    return '$count members · Tap to view';
  }

  @override
  String get stepRecipients => 'Recipients';

  @override
  String get stepContent => 'Message';

  @override
  String get selectAllOnline => 'Select all online';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get onlineOnly => 'Online only';

  @override
  String get noRecipients => 'No recipients selected';

  @override
  String selectedRecipients(int count) {
    return '$count selected';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return 'Sending to $count: $calls';
  }

  @override
  String get stepName => 'Name';

  @override
  String get stepMembers => 'Members';

  @override
  String get groupChatExplain =>
      'Group chats broadcast to a group callsign so every member can receive them. A group callsign is generated automatically and invitations are sent to the members you select.';

  @override
  String get noMembersSelected => 'No members selected';

  @override
  String get memberBlocked => 'Blocked';

  @override
  String get memberJoined => 'Joined';

  @override
  String get memberPending => 'Pending';

  @override
  String get memberDeclined => 'Declined';

  @override
  String get memberLeft => 'Left';

  @override
  String get memberTimeout => 'Timed out';

  @override
  String get unblock => 'Unblock';

  @override
  String get block => 'Block';

  @override
  String get groupOwner => 'Owner';

  @override
  String systemMemberJoined(String call) {
    return '$call joined the group';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call left the group';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call declined the invitation';
  }

  @override
  String get copyAllLogs => 'Copy all logs';

  @override
  String copiedLogs(int count) {
    return 'Copied $count log entries';
  }

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get noLogs => 'No logs yet';

  @override
  String get supportProject => 'Your support helps the project go further';

  @override
  String get continuousIteration => 'Continuous improvement';

  @override
  String get continuousIterationDesc =>
      'Continuously improving APRSlocus features and experience';

  @override
  String get sponsorSupport => 'Sponsor support';

  @override
  String get sponsorMethods => 'Ways to support';

  @override
  String qrCodeTitle(String title) {
    return '$title QR code';
  }

  @override
  String get qrLoadFailed => 'QR code image failed to load';

  @override
  String get qrSaveWechat => 'Long-press to save · Scan with WeChat to support';

  @override
  String get tapAnywhereClose => 'Tap anywhere to close';

  @override
  String vectorMapLoadFailed(String error) {
    return 'Vector map failed to load\n$error';
  }

  @override
  String get loadingVectorMap => 'Loading vector map…';

  @override
  String get updateChannel => 'Update channel';

  @override
  String serverReturned(int code) {
    return 'Server returned $code';
  }

  @override
  String get invalidResponseData => 'Invalid response format';

  @override
  String get noVersionsFound => 'No releases found';

  @override
  String get noWindowsInstaller => 'No Windows installer for this release';

  @override
  String get noApkInstaller => 'No APK for this release';

  @override
  String get connectingEllipsis => 'Connecting…';

  @override
  String downloadHttpError(int code) {
    return 'Download failed: HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return 'Downloaded $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return 'Package downloaded to:\n$path\n\nTap “Install” to open the system installer.\n\nIf Android blocks unknown apps, allow APRSlocus to install unknown apps in system settings.';
  }

  @override
  String windowsInstallHelp(String path) {
    return 'Installer saved to:\n$path\n\nTap “Run now” to launch it, or open the containing folder.';
  }

  @override
  String get openContainingFolder => 'Open containing folder';

  @override
  String get runNow => 'Run now';

  @override
  String get cannotRunInstaller =>
      'Could not start the installer. Open it manually from the containing folder.';

  @override
  String get cannotLaunchInstaller =>
      'Could not launch the installer. Open the package manually.';

  @override
  String get openPackageManually => 'Open the package in a file manager';

  @override
  String cannotOpenPackage(String error) {
    return 'Could not open package: $error';
  }

  @override
  String get installPermissionTitle => 'Allow app installation';

  @override
  String get installPermissionDesc =>
      'APRSlocus is not allowed to install apps.\n\nTap “Settings”, allow this app to install unknown apps, then return and try again.';

  @override
  String get recheck => 'Check again';

  @override
  String newVersionTitle(String version) {
    return 'New version v$version available';
  }

  @override
  String repoLatestTitle(String version) {
    return 'Latest repository version v$version';
  }

  @override
  String get checkingLatest => 'Checking latest version…';

  @override
  String get connectingGitCode => 'Connecting to GitCode';

  @override
  String get noReleaseNotes => 'No release notes';

  @override
  String noInstallerHistoryHint(String platform) {
    return 'No $platform package for this release. Choose a downloadable version from History.';
  }

  @override
  String get latestVersionLabel => 'Latest version';

  @override
  String packageSize(String platform, String size) {
    return '$platform package size: $size';
  }

  @override
  String get updateContents => 'What’s new';

  @override
  String get redownload => 'Download again';

  @override
  String get downloadInstaller => 'Download installer';

  @override
  String get downloadAndInstall => 'Download & install';

  @override
  String get localPackageExists => 'A downloaded package is already available';

  @override
  String get packageDeleted => 'Package deleted';

  @override
  String versionCount(int count) {
    return '$count versions';
  }

  @override
  String get noInstaller => 'No package';

  @override
  String get download => 'Download';

  @override
  String get viewChangelog => 'View changelog';

  @override
  String versionChangelog(String version) {
    return 'v$version changelog';
  }

  @override
  String get gotIt => 'Got it';

  @override
  String get leaveAction => 'Leave';

  @override
  String localRepoVersion(Object latest, Object local) {
    return 'Local v$local · Latest repository v$latest';
  }

  @override
  String get unverified => 'Unverified';

  @override
  String get passcodeUnverifiedHint => '-1 (unverified)';

  @override
  String get passcodeMessageWarning =>
      'APRS-IS login passcode. Using -1 prevents normal message send/receive.';

  @override
  String get settingsStationIdentitySubtitle => 'Callsign, SSID and comment';

  @override
  String get settingsDisplayInfoSubtitle => 'My symbol and current position';

  @override
  String get settingsLocSourceSubtitle => 'Choose position source';

  @override
  String get settingsBeaconSubtitle => 'Transmit interval & report content';

  @override
  String get settingsManualLocSubtitle =>
      'Manual input or map pick when no fix';

  @override
  String get settingsManualLocHint =>
      'When auto-location is unavailable, enter coordinates manually or pick on the map for beacon reporting and station distance calculation.';

  @override
  String get settingsConnStatusSubtitle => 'Connection status and info';

  @override
  String get settingsServerSubtitle => 'APRS-IS server and passcode';

  @override
  String get settingsFilterSubtitle => 'Filter center and radius';

  @override
  String get settingsReceivePrefSubtitle =>
      'Receive by country/region or callsign';

  @override
  String get settingsGeneralSubtitle =>
      'Theme, language and coordinate display';

  @override
  String get settingsMapSubtitle => 'Map type and display';

  @override
  String get settingsChatStatsSubtitle => 'Message and contact statistics';

  @override
  String get settingsChatManageSubtitle => 'Contacts and chat data';

  @override
  String get settingsClearDataSubtitle => 'Delete local records';

  @override
  String get settingsLabSubtitle => 'Experimental features';

  @override
  String get settingsDevSubtitle => 'Debugging and testing';

  @override
  String get settingsFilterHint =>
      'Only receive station packets within the configured range';

  @override
  String get settingsReceivePrefHint =>
      'Besides range filter, receive stations by country/region group or exact callsign';

  @override
  String get settingsContribCodeOptimization => 'Code optimization';

  @override
  String get eggBg2hcb => 'Life is all meow-meow and mimi~';

  @override
  String get deviceInfoTitle => 'Device identification';

  @override
  String get deviceToCall => 'To-call';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceClass => 'Device class';

  @override
  String get deviceFilter => 'Device filter';

  @override
  String get lookupQrz => 'QRZ callsign';

  @override
  String get lookupAprsFi => 'aprs.fi position';

  @override
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => 'Station page';

  @override
  String get aprsTvMap => 'View on map';

  @override
  String get linkOpenFailed => 'Unable to open link';

  @override
  String get beaconAutoAskTitle => 'Connected — auto-report your position?';

  @override
  String get beaconAutoAskDesc =>
      'Let APRSlocus automatically beacon your position while connected? Recommended for mobile use. Choose no to receive only (you can still send one manually anytime).';

  @override
  String get beaconAutoYes => 'Auto-report';

  @override
  String get beaconAutoNo => 'Receive only';

  @override
  String get beaconOffChip => 'Auto-report off';

  @override
  String get quickTrackCreate => 'New track group';

  @override
  String get quickTrackHint =>
      'Pick stations you received, or type callsigns — track them on the map directly, no chat group required.';

  @override
  String get quickTrackName => 'Name (optional)';

  @override
  String get quickTrackPickLabel => 'Choose stations to track';

  @override
  String get quickTrackNoStations =>
      'No stations received yet — type callsigns below (comma separated)';

  @override
  String get quickTrackManualHint => 'Type callsigns, e.g. BG7PGW,BG7LMW';

  @override
  String get quickTrackStart => 'Start tracking';

  @override
  String get quickTrackNeedMembers => 'Pick or type at least one callsign';

  @override
  String get weatherPanelTitle => 'Weather · Ham Tips';

  @override
  String get weatherPanelSub => 'QWeather · Current Location';

  @override
  String get weatherRefresh => 'Refresh';

  @override
  String get weatherPowered => 'Powered by QWeather · APRSlocus';

  @override
  String get weatherCurLoc => 'Current location';

  @override
  String get weatherNoLoc =>
      'No location yet — enable location in My Station to view weather';

  @override
  String get weatherUnavail => 'Weather service unavailable';

  @override
  String get weatherDataFail => 'Failed to fetch weather data';

  @override
  String get weatherConnFail => 'Weather service connection failed';

  @override
  String get weatherCloud => 'Cloud';

  @override
  String get weatherDew => 'Dew pt';

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherWindDir => 'Wind dir';

  @override
  String get weatherWindScale => 'Wind';

  @override
  String get weatherWindSpeed => 'Wind spd';

  @override
  String get weatherPressure => 'Pressure';

  @override
  String get weatherVis => 'Visibility';

  @override
  String get weatherPrecip => 'Precip.';

  @override
  String weatherFeels(String v) {
    return 'Feels $v°';
  }

  @override
  String weatherObserved(String t) {
    return 'Observed $t';
  }

  @override
  String get hamTitle => 'Ham radio tips';

  @override
  String get hamNoData =>
      'Once weather is loaded, tips on antenna setup, operating and lightning safety will appear';

  @override
  String get hamStorm1 =>
      'Thunderstorm: do NOT set up or operate antennas outdoors! Disconnect feed lines to avoid lightning surge damage';

  @override
  String get hamStorm2 =>
      'If already set up, take it down promptly; switch to indoor repeater / HF listening and keep gear dry';

  @override
  String get hamRain =>
      'Precipitation: bring rain covers / dry boxes, seal connectors with tape or heat-shrink, keep feed lines drained';

  @override
  String get hamCold =>
      'Cold / snow: Li-ion capacity drops — carry spare batteries kept warm; watch SWR if ice forms on antennas';

  @override
  String hamWind(String w) {
    return 'Wind $w: guy and secure antennas firmly; lower beams / long wires when packing up';
  }

  @override
  String hamHot(String t) {
    return 'Heat $t°C: stay hydrated; avoid long full-power transmissions that overheat your gear';
  }

  @override
  String hamHumid(String h) {
    return 'Humidity $h%: moisture hurts insulation and antenna efficiency; more VHF/UHF loss; keep connectors rust-free';
  }

  @override
  String hamFog(String v) {
    return 'Low visibility ($v km): drive carefully; fog can create ducts — try distant VHF/UHF contacts';
  }

  @override
  String get hamGood =>
      'Great weather for operating! Try repeaters / simplex on VHF-UHF; HF ionosphere shifts in the evening';

  @override
  String hamWindExtra(String w) {
    return 'Wind $w: still guy the antenna and stay safe in the field';
  }

  @override
  String get hamStorm3 =>
      'Lightning approaching: disconnect the antenna feedline from your rig, move it outdoors to a ground rod to bleed static, switch off and unplug mains power so surges cannot enter via AC or LAN; do not use outdoor antennas or corded phones';

  @override
  String get hamStorm4 =>
      'Static crashes (QRN) surge around thunderstorms and HF noise floor rises; wait about 30 minutes after lightning stops before raising antennas and transmitting again';

  @override
  String get hamExtreme =>
      'Torrential/extreme rain: watch for flash floods, standing water and rockfall — never set up on riverbanks or low ground; add a drip loop where the feedline enters the wall';

  @override
  String hamGale(String w) {
    return 'Wind force $w: do NOT climb towers or masts! Lower or lay down Yagis and long wires, and check guy ropes, anchors and mast stays';
  }

  @override
  String get hamIce =>
      'Ice on antennas and feedlines raises SWR and adds ice loading: do not force full power, first check guy tension and wait until ice melts before normal operation';

  @override
  String get hamFrost =>
      'Below 0℃: lithium battery capacity drops sharply — keep spares warm in a pocket; guard against frostbite on hands and face, carry hand warmers';

  @override
  String get hamHeat2 =>
      'Heat makes PAs and PSUs derate: lower power, shorten continuous transmissions and make sure there is proper ventilation';

  @override
  String get hamDust =>
      'Dust storm: fine sand in connectors and insulators causes leakage and noise — use dust caps; dry friction builds static, so ensure a good ground bleed';

  @override
  String get hamAir =>
      'Poor air quality: wear a mask outdoors and limit exertion; pollution films on antenna insulators add leakage noise, so clean the antenna afterwards';

  @override
  String hamDew(String d) {
    return 'Dew point spread only $d℃ — air is near saturation: gear and feedlines may condense moisture; let equipment warm up and dry before powering on to avoid shorts';
  }

  @override
  String hamUV(String u) {
    return 'UV index $u (high): protect yourself from sunburn during field work — long exposure also ages coax jackets and cable ties quickly';
  }

  @override
  String hamLowPressure(String p) {
    return 'Low pressure ($p hPa): weather is becoming unsettled — for long field sessions keep an escape route and watch nearby warnings';
  }

  @override
  String hamHighPressure(String p) {
    return 'High, steady pressure ($p hPa): inversions form easily and VHF/UHF tropospheric ducting is possible — try beyond-line-of-sight direct or repeater contacts';
  }

  @override
  String get hamGrayLine =>
      'You are in the sunrise/sunset grey line: 20/40m HF propagation peaks now — the golden window for long-haul DX';

  @override
  String get hamNight =>
      'D-layer fades at night: 80/40m absorption drops with lower noise — great for regional and nighttime long-distance work';

  @override
  String get hamRainFade =>
      'Heavier rain causes rain fade above 1.2GHz: for microwave and EME work, drop to a lower band or wait for the rain to ease';

  @override
  String get hamShower =>
      'Showers come and go quickly: bring a rain cover, watch the cloud movement, and stop transmitting before removing the feedline';

  @override
  String get hamLevelDanger => 'Safety';

  @override
  String get hamLevelWarn => 'Caution';

  @override
  String get hamLevelGood => 'Propagation';

  @override
  String get hamLevelTip => 'Tip';

  @override
  String hamMore(String n) {
    return 'Show all $n tips';
  }

  @override
  String get hamLess => 'Collapse';

  @override
  String get weatherForecast3 => '3-Day Forecast';

  @override
  String get weatherDaily15 => 'View 15-day weather';

  @override
  String get weatherDaily15Title => '15-Day Weather Trend';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherTomorrow => 'Tomorrow';

  @override
  String get weatherDayAfter => 'Day after';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': 'Mon',
      '2': 'Tue',
      '3': 'Wed',
      '4': 'Thu',
      '5': 'Fri',
      '6': 'Sat',
      '7': 'Sun',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => 'Sunrise';

  @override
  String get weatherSunset => 'Sunset';

  @override
  String get weatherUV => 'UV';

  @override
  String get weatherDetails => 'Details';

  @override
  String get weatherAQIPrimary => 'Primary';

  @override
  String get airExcellent => 'Excellent';

  @override
  String get airGood => 'Good';

  @override
  String get airModerate => 'Light pollution';

  @override
  String get airUnhealthy => 'Moderate pollution';

  @override
  String get airVeryUnhealthy => 'Heavy pollution';

  @override
  String get airHazardous => 'Severe pollution';

  @override
  String get weatherAir => 'AQI';

  @override
  String get issStation => 'ISS';

  @override
  String get applyStationFilter => 'Apply station filter to map';

  @override
  String get stationFilterOn => 'Filtered by station panel';

  @override
  String get stationList => 'Stations';

  @override
  String get statsPanel => 'Statistics';

  @override
  String get statsOverview => 'System overview';

  @override
  String get statsTotalRx => 'Packets RX';

  @override
  String get statsTotalTx => 'Packets TX';

  @override
  String get statsRate => 'Rate';

  @override
  String statsPerMin(String n) {
    return '$n/min';
  }

  @override
  String get statsStationsTotal => 'Stations';

  @override
  String get statsCap => 'Capacity';

  @override
  String get statsConn => 'Link';

  @override
  String get statsConnected => 'Connected';

  @override
  String get statsDisconnected => 'Offline';

  @override
  String get statsMyGrid => 'My grid';

  @override
  String get statsAprslocusUsers => 'APRSlocus users';

  @override
  String get statsFarthest => 'Farthest';

  @override
  String get statsStatusDist => 'Status breakdown';

  @override
  String get statsTypeDist => 'Type breakdown';

  @override
  String get statsGridDist => 'Grid square breakdown';

  @override
  String get statsGridHint => 'Stations per Maidenhead field (4 chars), ranked';

  @override
  String statsGridCount(String n) {
    return '$n grids';
  }

  @override
  String get statsGridEmpty => 'No station positions yet';

  @override
  String get statsDeviceDist => 'Device classes';

  @override
  String get statsOther => 'Other metrics';

  @override
  String get statsAvgSpeed => 'Avg speed';

  @override
  String get statsLastHeard => 'Last heard';

  @override
  String get statsPackets => 'Packets (recent)';

  @override
  String get statsNoData => 'No data';

  @override
  String get noStationsFiltered => 'No stations match the current filter';

  @override
  String get noStationsFilteredHint =>
      'The filter or receive range is too narrow. Clear the filter to retry; the receive range lives in Settings.';

  @override
  String get clearStationFilter => 'Clear filter';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get activeConditions => 'Active conditions';

  @override
  String get statsMovingCount => 'Moving';

  @override
  String get statsOnlineRate => 'Online rate';

  @override
  String get statsGridCountLabel => 'Grid squares';

  @override
  String get maxPackets => 'Packet history limit';

  @override
  String get maxPacketsTip =>
      'How many packets to keep on the packets page (default 2000; higher uses more memory)';

  @override
  String get maxTrackPts => 'Track point limit';

  @override
  String get maxTrackPtsTip =>
      'Track points kept per station (default 300; decides how far back a movement track can reach; a point is only stored after 20 m of movement)';

  @override
  String get onlineWindow => 'Online window (minutes)';

  @override
  String get onlineWindowTip =>
      'A station with no report for longer than this is treated as offline (default 5 minutes)';

  @override
  String get chatRecords => 'Chat history';

  @override
  String get chatRecordsCleared => 'Chat history cleared';

  @override
  String get deviceCat => 'Device';

  @override
  String get deviceCatDesc => 'Radio gear · coming soon';

  @override
  String get deviceSettings2 => 'Device settings';

  @override
  String get deviceSettingsSubtitle => 'Connect your radio equipment';

  @override
  String get underConstruction => 'Under construction — not open yet';

  @override
  String get underConstructionHint =>
      'This feature is still being built. Please stay tuned.';

  @override
  String get storageLimit => 'Data limits';

  @override
  String get storageLimitSubtitle => 'How much data to keep locally';

  @override
  String get connectionCard2 => 'APRS-IS connection';

  @override
  String get immersiveMap => 'Immersive map';

  @override
  String get immersiveMapTip =>
      'Navigation style: centered on you, heading-up, corner HUD';

  @override
  String get headingUp => 'Heading up';

  @override
  String get northUp => 'North up';

  @override
  String get followMe => 'Follow me';

  @override
  String get beaconCountdown => 'Next beacon';

  @override
  String get beaconOff => 'off';

  @override
  String get unlocated => 'No fix';

  @override
  String get platform => 'Platform';

  @override
  String get nearbyStations => 'Nearby stations';

  @override
  String get honorWall => 'Honors';

  @override
  String get accountHonors => 'Account honors';

  @override
  String get achievementsSection => 'Achievements';

  @override
  String get notLit => 'Not yet';

  @override
  String honorCriteriaLine(String c) {
    return 'How to earn: $c';
  }

  @override
  String get badgeFallback => 'Badge';

  @override
  String honoredBadges(String n, String m) {
    return '$n/$m badges unlocked';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m achievements';
  }

  @override
  String get beaconNotConnected => 'Not connected';

  @override
  String get beaconWaitingFix => 'Waiting for fix';

  @override
  String get beaconSoon => 'Due now';

  @override
  String beaconNextIn(String s) {
    return 'Next report in $s';
  }

  @override
  String get beaconImminent => 'Reporting now…';

  @override
  String get notifConnected => 'Connected';

  @override
  String get notifConnecting => 'Connecting';

  @override
  String get notifDisconnected => 'Disconnected';

  @override
  String notifOnline(String n) {
    return '$n online';
  }

  @override
  String notifRx(String n) {
    return 'RX $n';
  }

  @override
  String notifBeacon(String v) {
    return 'Beacon $v';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String deleteSelected(int n) {
    return 'Delete ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return 'Delete the $n selected chats? This cannot be undone.';
  }

  @override
  String get chatManageHint => 'Tap a chat to select; long-press also selects';

  @override
  String conversationsDeleted(int n) {
    return 'Deleted $n chats';
  }

  @override
  String get stationActions => 'Station actions';

  @override
  String get deleteStation => 'Delete station';

  @override
  String deleteStationConfirm(String name) {
    return 'Delete station $name? It will be removed from the station list and will reappear if its packets are received again.';
  }

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get copyCallsign => 'Copy callsign';

  @override
  String get callsignCopied => 'Callsign copied';

  @override
  String get stationDeleted => 'Station deleted';

  @override
  String get exportAdif => 'Export ADIF';

  @override
  String get exportAdifDesc =>
      'Export conversations as an ADIF log file, importable into Log4OM, N3FJP and similar';

  @override
  String get export => 'Export';

  @override
  String get adifHint =>
      'Each record contains only the callsign and the first message time (UTC); mode and band are omitted';

  @override
  String get adifNoSelection => 'Select at least one conversation to export';

  @override
  String adifExported(int n) {
    return 'Exported $n records';
  }

  @override
  String get adifExportDone => 'Export complete';

  @override
  String get adifExportFailed =>
      'Export failed — check storage permission or free space';

  @override
  String adifSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get adifCopyPath => 'Copy path';

  @override
  String get adifPathCopied => 'Path copied';

  @override
  String get chatShortLabel => 'Chat';

  @override
  String get adifLogFile => 'Export chats as a log file';

  @override
  String get adifOptions => 'Export options';

  @override
  String get adifMode => 'Mode (MODE)';

  @override
  String get adifNotWritten => 'Omit';

  @override
  String get adifModePkt => 'PKT (packet, recommended)';

  @override
  String get adifModeFm => 'FM (voice)';

  @override
  String get adifModeData => 'DATA (data)';

  @override
  String get adifSubModeAprs => 'Add SUBMODE=APRS';

  @override
  String get adifBand => 'Band (BAND)';

  @override
  String get adifStripSsid => 'Write base callsign only (drop -SSID)';

  @override
  String get adifPreview => 'Preview (record to be written)';

  @override
  String get adifModeRequiredHint =>
      'Most logbooks (including QRZ) require MODE; records without it are rejected';

  @override
  String get adifFreq => 'Frequency (FREQ)';

  @override
  String get adifFreqHint => 'In MHz; leave blank to omit';

  @override
  String get adifFreqInvalid => 'Enter a number in MHz, e.g. 144.640';
}
