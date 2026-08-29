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
  String get displaySettings => 'Display settings';

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
      'By default only Chinese callsigns are received. Add other countries as needed.';

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
  String get settingsDesc => 'Configure radio, location & connection';

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
  String get oobeWelcomeDesc => 'Start configuring your APRS radio';

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
  String get features => 'Features';

  @override
  String get openSource => 'Open-source acknowledgements';

  @override
  String get feedback => 'Feedback';

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
  String get beaconEnabled => 'Enable beacon';

  @override
  String get smartBeacon => 'SmartBeaconing';

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
      'Feed + conversation views, Chinese text and auto-reply support';

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
  String get featureFmoDesc => 'Auto-detect FMO data, structured info';

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
}
