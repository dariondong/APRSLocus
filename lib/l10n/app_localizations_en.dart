// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get about => 'About';

  @override
  String get aboutSubtitle => 'APRS tracking & mapping';

  @override
  String get aboutTitle => 'About';

  @override
  String get accept => 'Accept';

  @override
  String get accountHonors => 'Account honors';

  @override
  String get achievementWall => 'Achievement wall';

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m achievements';
  }

  @override
  String get achievementsSection => 'Achievements';

  @override
  String get activeConditions => 'Active conditions';

  @override
  String get add => 'Add';

  @override
  String get addContact => 'Add contact';

  @override
  String get addContactDesc => 'Enter a callsign to add it to contacts';

  @override
  String get addCountry => 'Add country/region';

  @override
  String get addOrFavoriteContact =>
      'Tap “Add” above or favorite a station on the map';

  @override
  String get addSpeedTier => 'Add speed tier';

  @override
  String get adifBand => 'Band (BAND)';

  @override
  String get adifCopyPath => 'Copy path';

  @override
  String get adifExportDone => 'Export complete';

  @override
  String get adifExportFailed =>
      'Export failed — check storage permission or free space';

  @override
  String adifExported(int n) {
    return 'Exported $n records';
  }

  @override
  String get adifFreq => 'Frequency (FREQ)';

  @override
  String get adifFreqHint => 'In MHz; leave blank to omit';

  @override
  String get adifFreqInvalid => 'Enter a number in MHz, e.g. 144.640';

  @override
  String get adifHint =>
      'Each record contains only the callsign and the first message time (UTC); mode and band are omitted';

  @override
  String get adifLogFile => 'Export chats as a log file';

  @override
  String get adifMode => 'Mode (MODE)';

  @override
  String get adifModeData => 'DATA (data)';

  @override
  String get adifModeFm => 'FM (voice)';

  @override
  String get adifModePkt => 'PKT (packet, recommended)';

  @override
  String get adifModeRequiredHint =>
      'Most logbooks (including QRZ) require MODE; records without it are rejected';

  @override
  String get adifNoSelection => 'Select at least one conversation to export';

  @override
  String get adifNotWritten => 'Omit';

  @override
  String get adifOptions => 'Export options';

  @override
  String get adifPathCopied => 'Path copied';

  @override
  String get adifPreview => 'Preview (record to be written)';

  @override
  String adifSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get adifStripSsid => 'Write base callsign only (drop -SSID)';

  @override
  String get adifSubModeAprs => 'Add SUBMODE=APRS';

  @override
  String get advancedCat => 'Advanced';

  @override
  String get advancedCatDesc => 'Lab · Developer';

  @override
  String get advancedDesc => 'Lab & developer tools';

  @override
  String get advancedSettings => 'Advanced settings';

  @override
  String get advancedSettings2 => 'Advanced settings';

  @override
  String get advancedSettingsSubtitle => 'Lab & developer tools';

  @override
  String get aiSupport => 'AI compute support';

  @override
  String get airExcellent => 'Excellent';

  @override
  String get airGood => 'Good';

  @override
  String get airHazardous => 'Severe pollution';

  @override
  String get airModerate => 'Light pollution';

  @override
  String get airUnhealthy => 'Moderate pollution';

  @override
  String get airVeryUnhealthy => 'Heavy pollution';

  @override
  String get all => 'All';

  @override
  String get allAprsSymbols => 'All APRS symbols';

  @override
  String get allChangelog => 'All changelogs';

  @override
  String get allDataCleared => 'All local data cleared';

  @override
  String get allowLandscape => 'Allow landscape orientation';

  @override
  String get alreadyDownloaded => 'Package downloaded';

  @override
  String get altitude => 'Altitude';

  @override
  String get amapGroup => 'Domestic';

  @override
  String androidInstallHelp(String path) {
    return 'Package downloaded to:\n$path\n\nTap “Install” to open the system installer.\n\nIf Android blocks unknown apps, allow APRSlocus to install unknown apps in system settings.';
  }

  @override
  String get appFilter => 'App';

  @override
  String get appInfo => 'App info';

  @override
  String get appInfoCopied => 'App info copied';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\nAuthor: BG7LZQ (Darion)\nWebsite: Theez.top';
  }

  @override
  String get appInstallDir => 'Install folder';

  @override
  String get appName => 'APRSlocus';

  @override
  String get appTagline => 'APRS tracking';

  @override
  String get appVersion => 'Version';

  @override
  String get appVersionDesc => 'Current app version';

  @override
  String get applyCoordinates => 'Apply coordinates';

  @override
  String get applyStationFilter => 'Apply station filter to map';

  @override
  String get aprsCallsignHint => 'APRS callsign, e.g. BV2AAA';

  @override
  String get aprsStatus => 'Standalone status packet';

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
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => 'Station page';

  @override
  String get aprsTvMap => 'View on map';

  @override
  String get aprslocusInfo => 'APRSlocus info';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get audioBackend => 'Audio backend';

  @override
  String audioBadFrames(int n) {
    return '$n aborted decodes (noise / out of sync)';
  }

  @override
  String get audioBaud => 'Bit rate';

  @override
  String get audioBaudTip =>
      'APRS on VHF is always 1200 bd (Bell 202); 300 bd is for HF';

  @override
  String get audioCaptureDesc => 'Demodulate AFSK 1200 from the mic/line input';

  @override
  String get audioCaptureStart => 'Start capture';

  @override
  String get audioCaptureStop => 'Stop capture';

  @override
  String get audioCaptureTitle => 'Audio capture';

  @override
  String get audioCsmaWait => 'Wait for a clear channel (ms)';

  @override
  String get audioCsmaWaitTip =>
      'How long to wait when the channel is busy; 0 = transmit immediately';

  @override
  String get audioLevel => 'Input level';

  @override
  String get audioLevelTip =>
      'The meter rises with a signal; \"Demod locked\" lights up when AFSK is detected';

  @override
  String get audioLoopbackHint =>
      'The self-test really does a modulate→demodulate round trip; on Android the microphone is paused while transmitting (half duplex)';

  @override
  String get audioMarkTip =>
      'Bell 202 specifies mark 1200 Hz / space 2200 Hz; the tolerance is only a few Hz';

  @override
  String get audioNeedPermission =>
      'Microphone permission (RECORD_AUDIO) is required — grant it and try again';

  @override
  String get audioRestart => 'Restart audio link';

  @override
  String get audioSampleRate => 'Sample rate';

  @override
  String get audioSampleRateTip =>
      '22050 Hz is the usual soundcard-TNC rate; use 44100/48000 if unsupported. Changing it restarts capture';

  @override
  String get audioSettings => 'Audio (soundcard TNC)';

  @override
  String get audioSettingsSubtitle =>
      'Send and receive AFSK 1200 packets with your soundcard';

  @override
  String get audioSpaceTip =>
      'Space tone. Together with mark it sets the FSK shift (1000 Hz nominal)';

  @override
  String audioStatDrop(int n) {
    return '$n bytes dropped while transmitting';
  }

  @override
  String audioStatRx(int n) {
    return '$n frames received';
  }

  @override
  String audioStatTx(int n) {
    return '$n frames sent';
  }

  @override
  String get audioStatsTitle => 'Audio statistics';

  @override
  String get audioStopTx => 'Stop transmit';

  @override
  String get audioSynced => 'Demod locked';

  @override
  String get audioTnc2Tip =>
      'Format SRC>DEST,PATH:info, e.g. BG7LZQ-9>APALOC:>TEST';

  @override
  String get audioToneMark => 'Mark tone (Hz)';

  @override
  String get audioToneSpace => 'Space tone (Hz)';

  @override
  String get audioTones => 'Tones (mark/space)';

  @override
  String get audioTxDelayLabel => 'Tx preamble (ms)';

  @override
  String get audioTxDelayTip =>
      'Preamble length: lets the far-end demod lock and the radio key up';

  @override
  String get audioTxDesc => 'Listens before transmitting to avoid collisions';

  @override
  String get audioTxDisabled => '\"Allow transmit\" is off — receiving only';

  @override
  String get audioTxEnabled => 'Allow transmit';

  @override
  String get audioTxEnabledTip =>
      'When off, receive only — handy if you just want to monitor beacons';

  @override
  String get audioTxLevel => 'TX level';

  @override
  String get audioTxLevelClip =>
      'Clipped: lower the output amplitude below 0.8 (clipping adds harmonics)';

  @override
  String get audioTxLevelLow =>
      'Low level: the other side may not decode — raise amplitude and device volume';

  @override
  String get audioTxLevelTip =>
      'Before transmitting the media volume is raised to maximum and the mic is paused; a peak that is too low or clipped means the other side cannot decode';

  @override
  String audioTxPeak(int p, String sec, int flags) {
    return 'Peak $p% · ${sec}s · preamble $flags flags';
  }

  @override
  String get audioTxTitle => 'Audio transmit';

  @override
  String get audioUnlocked => 'Not locked';

  @override
  String get audioUnsupported =>
      'Real-time audio is not supported on this platform (WAV file mode is available)';

  @override
  String get audioWavCanceled => 'Cancelled';

  @override
  String get audioWavCopyPath => 'Copy path';

  @override
  String get audioWavDecodeAction => 'Decode this WAV';

  @override
  String get audioWavDesc =>
      'Decode a recording offline, or export a packet as audio';

  @override
  String get audioWavExportAction => 'Export this packet';

  @override
  String get audioWavExportToDownloads => 'Export to Downloads';

  @override
  String audioWavFailed(String err) {
    return 'File I/O failed: $err';
  }

  @override
  String audioWavFound(int n) {
    return 'Decoded $n packet(s)';
  }

  @override
  String get audioWavImportAction => 'Choose WAV file';

  @override
  String get audioWavMobileHint =>
      'Android cannot write arbitrary paths: the file goes to Downloads/APRSlocusAudio — copy it to a PC for Direwolf or a radio';

  @override
  String get audioWavNone =>
      'No packets decoded (maybe not an AFSK 1200 recording)';

  @override
  String get audioWavPath => 'File path';

  @override
  String get audioWavPathCopied => 'Path copied';

  @override
  String get audioWavPickHint => 'On desktop, enter the WAV path below';

  @override
  String audioWavSavedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get audioWavTitle => 'WAV file mode';

  @override
  String get audioWavTnC2 => 'Packet to export (TNC2)';

  @override
  String get audioWavVerifyFailed =>
      'Self-check failed: the generated audio does not decode back';

  @override
  String audioWavWritten(String path) {
    return 'Written to $path';
  }

  @override
  String get audioWiringHint =>
      'Use an audio cable to the radio (headphone out → data/mic jack). Phone speakers roll off badly at 2200 Hz, so acoustic coupling rarely decodes. If the far end is Direwolf, first verify with the exported WAV: if that decodes, the problem is the audio path, not the protocol';

  @override
  String get author => 'Author';

  @override
  String get authorCall => 'Callsign';

  @override
  String get authorName => 'Darion';

  @override
  String get autoReply => 'Auto-reply';

  @override
  String get autoSaveStations => 'Save station data automatically';

  @override
  String get back => 'Back';

  @override
  String get backToTop => 'Back to top';

  @override
  String get backgroundRunTip =>
      'Background operation: allow APRSlocus to run in the background, disable battery optimization, and allow autostart to keep beaconing active.';

  @override
  String get backupCatChats => 'Group chats';

  @override
  String get backupCatChatsDesc => 'Groups, members and read state';

  @override
  String get backupCatHonors => 'Achievements & honours';

  @override
  String get backupCatHonorsDesc => 'Unlocks, counters and default badge';

  @override
  String get backupCatMessages => 'Messages';

  @override
  String get backupCatMessagesDesc => 'Direct messages and read positions';

  @override
  String get backupCatSettings => 'Settings';

  @override
  String get backupCatSettingsDesc =>
      'Station, beacon, map, filters, sources, server';

  @override
  String get backupCatStations => 'Stations & contacts';

  @override
  String get backupCatStationsDesc =>
      'Favourites, manual contacts and their notes';

  @override
  String get backupCatTranslate => 'Translation settings';

  @override
  String get backupCatTranslateDesc =>
      'Providers, keys and language preferences';

  @override
  String get backupCopyDone => 'Backup copied to clipboard';

  @override
  String get backupCopyJson => 'Copy to clipboard';

  @override
  String get backupDesc =>
      'The backup is a JSON file you can restore after switching or reinstalling. Import overwrites per group and cannot be undone.';

  @override
  String get backupEntryDesc => 'Pack settings and data into a JSON file';

  @override
  String get backupErrEmpty => 'The backup contains nothing to import';

  @override
  String get backupErrNotBackup => 'This is not an APRSlocus backup file';

  @override
  String get backupErrNotJson => 'The file is not valid JSON';

  @override
  String get backupErrRead => 'Could not read the backup file';

  @override
  String get backupErrSchemaNewer =>
      'The backup comes from a newer APRSlocus — update the app first';

  @override
  String get backupErrTooLarge =>
      'The backup is larger than 32 MB and cannot be read';

  @override
  String get backupErrUnsupported =>
      'Picking files is not supported here — paste from the clipboard instead';

  @override
  String get backupExport => 'Export backup';

  @override
  String get backupExportDesc =>
      'Pick what to include, then save to a file or copy as text';

  @override
  String get backupExportDone => 'Backup exported';

  @override
  String get backupExportFailed =>
      'Export failed — check storage permission or free space';

  @override
  String get backupExportToFile => 'Save to file';

  @override
  String backupExportedAt(String t) {
    return 'Exported $t';
  }

  @override
  String backupFromVersion(String v) {
    return 'From version $v';
  }

  @override
  String get backupImport => 'Import backup';

  @override
  String get backupImportConfirm =>
      'The selected groups will be overwritten and this cannot be undone. Consider exporting a backup of the current data first.';

  @override
  String get backupImportConfirmTitle => 'Import this backup?';

  @override
  String get backupImportDesc => 'Choose a backup JSON file exported earlier';

  @override
  String get backupImportNothing =>
      'The backup has no data for the selected groups';

  @override
  String get backupImportSelected => 'Import selected';

  @override
  String backupImported(int n) {
    return 'Imported $n items';
  }

  @override
  String backupItems(int n) {
    return '$n items';
  }

  @override
  String get backupLater => 'Later';

  @override
  String get backupNoSelection => 'Select at least one group';

  @override
  String get backupPaste => 'Paste from clipboard';

  @override
  String get backupPasteEmpty => 'No text in the clipboard';

  @override
  String get backupPickFile => 'Choose backup file';

  @override
  String get backupPreview => 'Backup contents';

  @override
  String get backupRestartHint =>
      'Data is saved; restart the app for everything to take effect (achievements, translation, server connection).';

  @override
  String get backupRestartNow => 'Quit app';

  @override
  String get backupRestartTitle => 'Import complete';

  @override
  String backupSavedTo(String path) {
    return 'Saved to: $path';
  }

  @override
  String get backupSecurityTip =>
      'The backup contains your callsign, server passcode and API keys — keep it safe.';

  @override
  String get backupSelectAll => 'Select all';

  @override
  String backupSkipped(int n) {
    return 'Skipped $n unknown entries';
  }

  @override
  String get backupSubtitle => 'Export or import settings and data';

  @override
  String get backupThemeImagesHint =>
      'The backup will embed the images your themes use. Without them, a restored theme falls back to built-in icons.';

  @override
  String get backupThemeImagesOff =>
      'Images excluded: a smaller backup, but a restored theme will be missing its background and custom icons';

  @override
  String get backupTitle => 'Backup & restore';

  @override
  String get backupWebHint =>
      'On the web, use “copy to clipboard / paste from clipboard”.';

  @override
  String get badgeFallback => 'Badge';

  @override
  String get badgeWall => 'Badge wall';

  @override
  String get beacon => 'Position beacon';

  @override
  String get beaconAltLabel => 'Altitude (m, empty = use the fix)';

  @override
  String get beaconAltNone =>
      'Sent with the fix automatically · no altitude yet';

  @override
  String get beaconAntHeightLabel => 'Antenna height (ft)';

  @override
  String beaconAttachedHr(String hr) {
    return 'HR $hr';
  }

  @override
  String get beaconAttachedNone => 'no heart rate';

  @override
  String get beaconAutoAskDesc =>
      'Let APRSlocus automatically beacon your position while connected? Recommended for mobile use. Choose no to receive only (you can still send one manually anytime).';

  @override
  String get beaconAutoAskTitle => 'Connected — auto-report your position?';

  @override
  String get beaconAutoNo => 'Receive only';

  @override
  String get beaconAutoYes => 'Auto-report';

  @override
  String get beaconCat => 'Beaconing';

  @override
  String get beaconCatDesc => 'GPS · Beaconing · Manual position';

  @override
  String get beaconCoarseFix => 'Network fix · auto beacon paused';

  @override
  String beaconCoarseForced(String s) {
    return 'Network fix (coarse) · $s';
  }

  @override
  String get beaconCoarseForcedNote => 'Beaconing a network (coarse) fix';

  @override
  String get beaconCoarseHint =>
      'The current fix comes from the network (coarse, often hundreds of metres off) — automatic reports are paused and resume once GPS is back. You can still beacon manually.';

  @override
  String get beaconContent => 'Beacon contents';

  @override
  String get beaconContentDesc => 'Sent with each position beacon';

  @override
  String beaconCount(int count) {
    return 'Beacons $count';
  }

  @override
  String get beaconCountdown => 'Next beacon';

  @override
  String get beaconDisabled => 'Disabled';

  @override
  String get beaconEnabled => 'Enable beaconing';

  @override
  String get beaconForceCoarse => 'Beacon network (coarse) fixes anyway';

  @override
  String get beaconForceCoarseHint =>
      'Off by default: network fixes (cell / Wi-Fi) are often hundreds of metres off, so beaconing them announces a wrong coordinate to everyone. Turn this on only when the device has no GPS (tablet, network-only). Coarse points are still filtered the usual way for the map and track, so those do not get jumpy. Manual \"beacon now\" is unaffected.';

  @override
  String get beaconGainLabel => 'Gain (dB)';

  @override
  String beaconGarminNext(String s, String hr) {
    return 'Garmin · $s · ❤$hr';
  }

  @override
  String get beaconGarminSource => 'Beaconing from Garmin LiveTrack';

  @override
  String get beaconImminent => 'Reporting now…';

  @override
  String get beaconInterval => 'Beacon interval (sec)';

  @override
  String get beaconIntervalLabel => 'Interval';

  @override
  String get beaconIntervalTip => 'Position beacon interval, minimum 5 seconds';

  @override
  String get beaconNetInterval => 'Network-only interval (s)';

  @override
  String get beaconNetIntervalTip =>
      'In network-only mode a fixed interval is used; cell/Wi-Fi fixes have no reliable speed, so smart beaconing (speed / distance / turn) is not used';

  @override
  String beaconNextIn(String s) {
    return 'Next report in $s';
  }

  @override
  String get beaconNotConnected => 'Not connected';

  @override
  String get beaconNow => 'Beacon now';

  @override
  String get beaconOff => 'off';

  @override
  String get beaconOffChip => 'Auto-report off';

  @override
  String beaconPhgPreview(String phg) {
    return 'The packet will carry: $phg';
  }

  @override
  String get beaconPhgTip =>
      'Power, antenna height and gain share one PHG data extension: filling any of them encodes and sends all of them (the spec defines it as a single fixed 7-byte field). Power takes the largest step not exceeding the real value: 25 W reports 25, and so does 30 W, because over-reporting inflates your coverage circle. Antenna height is measured above average local terrain - a different quantity from the /A= altitude sent automatically above.';

  @override
  String get beaconPowerLabel => 'Power (W)';

  @override
  String get beaconRfBeaconOff => 'RF beacon is off';

  @override
  String get beaconRfEnableAction => 'Enable RF beacon';

  @override
  String get beaconRfEnableHint =>
      'Automatic transmission on an RF source requires the “RF beacon” switch. Until then no position is transmitted automatically (and the countdown does not run).';

  @override
  String get beaconRfEnableWarn =>
      'Transmission uses your callsign — operate within your licence';

  @override
  String get beaconRfEnabled => 'RF beacon enabled — will transmit on schedule';

  @override
  String beaconSentAprsIs(String grid) {
    return 'Position beacon sent · Grid $grid · Sent to APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return 'Position beacon sent · Grid $grid · Demo';
  }

  @override
  String get beaconSettings => 'Beaconing';

  @override
  String get beaconSettingsDetail => 'GPS source, beaconing & manual location';

  @override
  String get beaconSoon => 'Due now';

  @override
  String get beaconTotalMileage => 'Total distance';

  @override
  String get beaconTripMileage => 'Trip distance';

  @override
  String get beaconWaitingFix => 'Waiting for fix';

  @override
  String get beaconWarnBody =>
      'APRS-IS recommends a minimum 60-second beacon interval for mobile stations. Sending faster may be considered abuse and could lead to disconnection. Keep this interval anyway?';

  @override
  String get beaconWarnFix => 'Set to 60 s';

  @override
  String get beaconWarnKeep => 'Keep anyway';

  @override
  String get beaconWarnTitle => 'Beacon interval too short';

  @override
  String get beaconingSection => 'Beaconing';

  @override
  String get beaconsSent => 'Beacons sent';

  @override
  String beaconsSentCount(String n) {
    return '$n';
  }

  @override
  String get beaconsSentLabel => 'Sent';

  @override
  String get bearing => 'Bearing';

  @override
  String get block => 'Block';

  @override
  String get broadcastContentHint => 'Enter message to broadcast…';

  @override
  String get broadcastHint =>
      'Each message is sent separately to every recipient';

  @override
  String get broadcastMessage => 'Broadcast message';

  @override
  String broadcastSent(int count) {
    return 'Sent to $count recipients';
  }

  @override
  String get broadcastShort => 'Broadcast';

  @override
  String get browse => 'Browse';

  @override
  String get callComment => 'Station comment';

  @override
  String get callCommentEmpty => 'Not set · tap to type';

  @override
  String get callCommentHint => 'Comment sent with position beacons';

  @override
  String get callSsid => 'Callsign · SSID';

  @override
  String get callSymbol => 'Station symbol';

  @override
  String get callSymbolDesc => 'Symbol sent with position beacons';

  @override
  String get callsign => 'Callsign';

  @override
  String get callsignCopied => 'Callsign copied';

  @override
  String get callsignExample => 'Callsign, e.g. BG7ABC';

  @override
  String get callsignMin3 => 'Callsign must be at least 3 characters';

  @override
  String get cancel => 'Cancel';

  @override
  String get cancelInstall => 'Cancel';

  @override
  String get cannotLaunchInstaller =>
      'Could not launch the installer. Open the package manually.';

  @override
  String cannotOpenPackage(String error) {
    return 'Could not open package: $error';
  }

  @override
  String get cannotRunInstaller =>
      'Could not start the installer. Open it manually from the containing folder.';

  @override
  String get chatCat => 'Chat';

  @override
  String get chatCatDesc => 'History · Contacts';

  @override
  String get chatCleared => 'Chat history cleared';

  @override
  String get chatHistory => 'Chat history';

  @override
  String get chatManageHint => 'Tap a chat to select; long-press also selects';

  @override
  String get chatRecords => 'Chat history';

  @override
  String get chatRecordsCleared => 'Chat history cleared';

  @override
  String get chatSettings => 'Chat settings';

  @override
  String get chatSettings2 => 'Chat settings';

  @override
  String get chatSettingsDetail => 'Messages, contacts & chat data';

  @override
  String get chatSettingsSubtitle => 'Message history & contacts';

  @override
  String get chatShortLabel => 'Chat';

  @override
  String get chatToGroupHint => 'Message the group…';

  @override
  String chatToHint(Object call) {
    return 'Message $call…';
  }

  @override
  String chatWithTitle(Object call) {
    return 'Chat with $call';
  }

  @override
  String get checkUpdate => 'Check update';

  @override
  String get checking => 'Checking for updates…';

  @override
  String get checkingGitCode => 'Checking GitCode repository';

  @override
  String get checkingLatest => 'Checking latest version…';

  @override
  String get chooseSsidSuffix => 'Choose SSID suffix';

  @override
  String get chooseSymbol => 'Choose station symbol';

  @override
  String get clear => 'Clear';

  @override
  String get clearAll => 'Clear all';

  @override
  String get clearAllData => 'Clear all data';

  @override
  String get clearAllDataConfirm =>
      'Clear all local data? This cannot be undone.';

  @override
  String get clearAllDataIntro => 'This will delete all local data below:';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearData => 'Clear data';

  @override
  String clearGroupChatConfirm(Object name) {
    return 'Clear the chat history of “$name”? This cannot be undone.';
  }

  @override
  String get clearLogs => 'Clear logs';

  @override
  String get clearMessages => 'Clear all chat history';

  @override
  String get clearPackets => 'Clear packets';

  @override
  String get clearPackets2 => 'Clear packets';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get clearStationFilter => 'Clear filter';

  @override
  String get clearStations => 'Clear station list';

  @override
  String clearStationsConfirm(String n) {
    return 'Clear all stations? $n in total. This cannot be undone (messages, logs and packets are not affected).';
  }

  @override
  String get clearedPackets => 'Packets cleared';

  @override
  String get close => 'Close';

  @override
  String get codeContributionI18n => 'Internationalization / English UI';

  @override
  String get codeContributionTranslation => 'Translation';

  @override
  String get codeContributionZhTw => 'Traditional Chinese UI';

  @override
  String get codeContributions => 'Code contributions';

  @override
  String get configChanged => 'Configuration changed';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmClear => 'Clear';

  @override
  String get confirmClearAllData => 'Clear all data';

  @override
  String get confirmDelete => 'Delete this item?';

  @override
  String confirmDeleteMessages(String n) {
    return 'Delete all $n chat messages? This cannot be undone.';
  }

  @override
  String get confirmRestartOobe =>
      'This will re-open the setup wizard to configure callsign, receive region, etc.\nYour current settings will be kept.';

  @override
  String connAudioConnected(String rate) {
    return 'Audio link online · $rate';
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
  String get connAudioSourceHint =>
      'Audio mode does not use the server, filters or KISS settings';

  @override
  String connAutoReconnect(int seconds) {
    return 'Connection lost · Reconnecting in ${seconds}s…';
  }

  @override
  String connConnectingAudio(String name) {
    return 'Opening audio ($name)…';
  }

  @override
  String connConnectingPkwdwpl(String arg) {
    return 'Connecting to PKWDWPL ($arg)…';
  }

  @override
  String connConnectingTarget(String target) {
    return 'Connecting to $target…';
  }

  @override
  String get connDemoBeacon =>
      'Not connected · Position beacon recorded (demo)';

  @override
  String get connManuallyDisconnected =>
      'Not connected · Manually disconnected';

  @override
  String connOnline(String call) {
    return 'Connected · $call online';
  }

  @override
  String get connPasscodeInvalid =>
      'Connected · Unverified (Passcode may be incorrect)';

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL connected · $arg';
  }

  @override
  String connPositionSent(String call) {
    return 'Connected · Position beacon sent ($call)';
  }

  @override
  String connRetry(int seconds) {
    return 'Connection failed · Retrying in ${seconds}s…';
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
  String connRetryTnc(int n) {
    return 'TNC connection failed · retrying in ${n}s…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'TNC connection failed ($e) · retrying in ${n}s…';
  }

  @override
  String get connTapToConnect => 'Not connected · Tap connect to join APRS-IS';

  @override
  String connTncConnected(String arg) {
    return 'TNC connected · $arg';
  }

  @override
  String connTncLinkLost(int n) {
    return 'TNC link lost · reconnecting in ${n}s…';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC connected · position sent ($arg)';
  }

  @override
  String get connTncSourceHint =>
      'TNC mode does not use a server or filters, so those settings are disabled';

  @override
  String get connectAction => 'Connect';

  @override
  String get connectAprsIs => 'Connect APRS-IS';

  @override
  String get connectFailedCheckConfig =>
      'Connection failed; check the configuration';

  @override
  String get connectNearbyDesc =>
      'Connect to receive nearby station positions and messages';

  @override
  String get connectTncBar => 'Tap Connect to open the TNC link';

  @override
  String get connected => 'Connected';

  @override
  String get connectedAprsIs => 'Connected to APRS-IS';

  @override
  String get connecting => 'Connecting';

  @override
  String get connectingEllipsis => 'Connecting…';

  @override
  String get connectingGitCode => 'Connecting to GitCode';

  @override
  String get connectingServer => 'Connecting to server…';

  @override
  String connectingToServer(String server, int port) {
    return 'Connecting to $server:$port…';
  }

  @override
  String connectingToTnc(String name) {
    return 'Connecting TNC · $name';
  }

  @override
  String get connection => 'Connection';

  @override
  String get connectionCard2 => 'APRS-IS connection';

  @override
  String get connectionCat => 'Connection';

  @override
  String get connectionCatDesc => 'Server · Range filter';

  @override
  String get connectionSettings => 'Connection settings';

  @override
  String get connectionSettings2 => 'Connection settings';

  @override
  String get connectionSettingsSubtitle => 'APRS-IS server & receive range';

  @override
  String contactAdded(String call) {
    return 'Added contact $call';
  }

  @override
  String contactDeleted(String call) {
    return 'Deleted $call';
  }

  @override
  String get contactDesc => 'Message/contact filtering rules';

  @override
  String get contactList => 'Contacts';

  @override
  String get continueAnyway => 'Continue anyway';

  @override
  String get continuousIteration => 'Continuous improvement';

  @override
  String get continuousIterationDesc =>
      'Continuously improving APRSlocus features and experience';

  @override
  String get conversationMode => 'Chats';

  @override
  String get conversations => 'Chats';

  @override
  String conversationsDeleted(int n) {
    return 'Deleted $n chats';
  }

  @override
  String get coordDatum => 'Datum';

  @override
  String get coordDisplay => 'Coordinate display';

  @override
  String get coordsFormat => 'Coord format';

  @override
  String get copied => 'Copied';

  @override
  String get copiedAprslocusInfo => 'APRSlocus info copied';

  @override
  String get copiedClipboard => 'Copied to clipboard';

  @override
  String copiedCoordsValue(String coords) {
    return 'Coordinates copied: $coords';
  }

  @override
  String get copiedFmoInfo => 'FMO info copied';

  @override
  String copiedGridValue(String grid) {
    return 'Grid copied: $grid';
  }

  @override
  String copiedLogs(int count) {
    return 'Copied $count log entries';
  }

  @override
  String get copiedPacket => 'Packet copied';

  @override
  String get copy => 'Copy';

  @override
  String get copyAllLogs => 'Copy all logs';

  @override
  String get copyAppInfo => 'Copy app info';

  @override
  String get copyCallsign => 'Copy callsign';

  @override
  String get copyCoords => 'Copy coords';

  @override
  String get copyGrid => 'Copy grid';

  @override
  String get copyShareText => 'Copy share text';

  @override
  String countEntries(int count) {
    return '$count';
  }

  @override
  String countItems(int count) {
    return '$count';
  }

  @override
  String countTimes(int count) {
    return '$count times';
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
  String get countryUnrestricted =>
      'No country selected · no restriction (all stations)';

  @override
  String get course => 'Course';

  @override
  String get courseLabel => 'Course';

  @override
  String get create => 'Create';

  @override
  String get creditsSection => 'Credits';

  @override
  String get current => 'Current';

  @override
  String get currentVersion => 'Current APRSlocus version';

  @override
  String currentVsRepo(Object local, Object remote) {
    return 'Installed v$local · Latest v$remote';
  }

  @override
  String get darkMode => 'Dark mode';

  @override
  String get dataCat => 'Data';

  @override
  String get dataCatDesc => 'Clear local data';

  @override
  String get dataClearDesc =>
      'Clear local messages, packets, stations, and other data';

  @override
  String get dataMaintenance => 'Data maintenance';

  @override
  String get dataPersistence => 'Station persistence';

  @override
  String get dataSettings => 'Data settings';

  @override
  String get dataSettings2 => 'Data settings';

  @override
  String get dataSettingsSubtitle => 'Local data management';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => 'Global APRS network over the internet';

  @override
  String get dataSourceAudio => 'Audio (soundcard)';

  @override
  String get dataSourceAudioDesc =>
      'AFSK 1200 to/from a radio via mic/speaker or a soundcard cable';

  @override
  String get dataSourceAudioShort => 'Audio';

  @override
  String get dataSourceIgateHint =>
      'To run a gateway (relay RF packets to the internet), enable both APRS-IS and TNC/audio, then turn on “Gateway” below.';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL (Kenwood waypoints)';

  @override
  String get dataSourcePkwdwplDesc =>
      'Read the Kenwood \$PKWDWPL waypoint sentences from the radio over Bluetooth or serial (receive-only)';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL is a **receive-only** link: it brings in stations but never transmits (use APRS-IS / TNC / audio for transmitting)';

  @override
  String get dataSourceSubtitle => 'Where packets come from';

  @override
  String get dataSourceSwitchHint =>
      'Switching the data source disconnects the current link';

  @override
  String get dataSourceTitle => 'Data source';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc =>
      'Send and receive on air through a Bluetooth or serial TNC';

  @override
  String get dataSourceTxBadge => 'TX';

  @override
  String get dataSourceTxHint =>
      'You can enable several links at once to receive from all of them, but **only one transmits** (the dot on the right). Sending the same callsign over two links would duplicate packets.';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$m/$d/$y $w';
  }

  @override
  String get dateToday => 'Today';

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
  String get dateYesterday => 'Yesterday';

  @override
  String get datumGcj => 'GCJ-02';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String daysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get debugLabel => 'Debug';

  @override
  String get defaultLabel => 'Default';

  @override
  String get delete => 'Delete';

  @override
  String deleteAllChatsConfirm(int count) {
    return 'Delete all $count chat messages? This cannot be undone.';
  }

  @override
  String get deleteAllPackages => 'Delete all packages';

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return 'Delete $count downloaded packages ($size)? This cannot be undone.';
  }

  @override
  String deleteAllPackagesWithCount(Object count) {
    return 'Delete all packages ($count)';
  }

  @override
  String get deleteContact => 'Delete contact';

  @override
  String deleteContactConfirm(String call) {
    return 'Delete contact $call?';
  }

  @override
  String get deleteConversation => 'Delete chat';

  @override
  String deleteConversationConfirm(Object call) {
    return 'Delete the chat history with $call? The conversation will also be removed from the list. This cannot be undone.';
  }

  @override
  String get deleteGroup => 'Delete group';

  @override
  String deleteGroupConfirm(String name) {
    return 'Delete “$name”? This cannot be undone.';
  }

  @override
  String get deletePackage => 'Delete package';

  @override
  String deletePackageConfirm(Object file) {
    return 'Delete package $file?';
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
  String get deleteStation => 'Delete station';

  @override
  String deleteStationConfirm(String name) {
    return 'Delete station $name? It will be removed from the station list and will reappear if its packets are received again.';
  }

  @override
  String get deleteThisTier => 'Delete this tier';

  @override
  String get deleteTrackGroup => 'Delete track group';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return 'Delete track group “$name”?';
  }

  @override
  String get demo => 'Demo';

  @override
  String get deselectAll => 'Deselect all';

  @override
  String get devDesc => 'Developer tools';

  @override
  String get deviceCat => 'Device';

  @override
  String get deviceCatDesc => 'Radio gear · coming soon';

  @override
  String get deviceClass => 'Device class';

  @override
  String get deviceConflictDesc =>
      'When TNC and PKWDWPL point at the same device, the received data is split between them — the symptom is \"transmits fine but receives nothing\". Give one of them a different device. TNC takes priority: PKWDWPL will refuse to connect.';

  @override
  String get deviceConflictTitle => 'Two links are bound to the same device';

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
  String get deviceFilter => 'Device filter';

  @override
  String get deviceInUseByPkwdwpl => 'In use by PKWDWPL — cannot bind again';

  @override
  String get deviceInUseByTnc => 'In use by TNC — cannot bind again';

  @override
  String get deviceInfoTitle => 'Device identification';

  @override
  String get deviceLogDesc =>
      'Shows the log of the current source (TNC / audio switches automatically)';

  @override
  String get deviceLogTitle => 'Link log';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceOverviewSubtitle => 'Data source, link status and self-test';

  @override
  String get deviceOverviewTitle => 'Devices';

  @override
  String get deviceSettings2 => 'Device settings';

  @override
  String get deviceSettingsSubtitle => 'Connect your radio equipment';

  @override
  String get deviceToCall => 'To-call';

  @override
  String get diagAfskLevelFail =>
      'Waveform level too low (output is nearly silent)';

  @override
  String get diagAfskLoopback => 'AFSK modem loop';

  @override
  String diagAfskLoopbackFail(int n) {
    return 'Decoded $n frame(s) — expected 1';
  }

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return 'Modulate → demodulate identical ($samples samples @${rate}Hz)';
  }

  @override
  String get diagAudioPlatformWarn =>
      'No real-time audio — WAV file mode is still available';

  @override
  String get diagAudioSection => 'Audio (AFSK 1200)';

  @override
  String get diagAx25 => 'AX.25 framing';

  @override
  String get diagAx25Fail => 'AX.25 encoding failed (malformed packet)';

  @override
  String diagAx25Mismatch(String got) {
    return 'AX.25 round-trip mismatch, decoded: $got';
  }

  @override
  String get diagCapture => 'Audio capture';

  @override
  String diagCaptureFailed(String err) {
    return 'Could not start capture: $err';
  }

  @override
  String get diagCaptureNoData =>
      'No audio data received — check the input device and permissions';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return 'Received $bytes bytes @${rate}Hz';
  }

  @override
  String diagFailed(int n) {
    return '$n failed';
  }

  @override
  String get diagFcs => 'FCS check';

  @override
  String get diagFcsFail =>
      'FCS check is wrong (a one-byte change must be rejected)';

  @override
  String get diagFileDecodeFail =>
      'No packet decoded from the file (maybe not an AFSK 1200 recording)';

  @override
  String get diagFileIo => 'WAV file I/O';

  @override
  String diagFileIoOk(int rate) {
    return 'Write → read → decode identical @${rate}Hz';
  }

  @override
  String get diagFileReadFail => 'File read failed';

  @override
  String diagFileWriteFail(String err) {
    return 'File write failed: $err';
  }

  @override
  String get diagHint =>
      'Protocol loops run without a radio: rule out software first, then check devices and wiring';

  @override
  String get diagKissEscape => 'KISS escaping';

  @override
  String get diagKissEscapeFail =>
      'KISS unescaping failed (software issue — changing hardware will not help)';

  @override
  String get diagNoRealtime => 'not real-time';

  @override
  String diagPassed(int n) {
    return '$n passed';
  }

  @override
  String get diagPermission => 'Mic permission';

  @override
  String get diagPermissionOk => 'Granted';

  @override
  String get diagPlatform => 'Platform support';

  @override
  String diagPlatformOk(String name) {
    return 'Available · backend $name';
  }

  @override
  String get diagRun => 'Run self-test';

  @override
  String get diagRunning => 'Testing…';

  @override
  String get diagSkipped => 'Skipped (unsupported platform)';

  @override
  String get diagSpeaker => 'Speaker output';

  @override
  String diagSpeakerFail(String err) {
    return 'Playback failed: $err';
  }

  @override
  String get diagSpeakerOk => 'Test tone played';

  @override
  String get diagSubtitle =>
      'Checks protocol, permissions and devices layer by layer';

  @override
  String get diagTitle => 'Link self-test';

  @override
  String get diagTncLoopback => 'TNC protocol loop';

  @override
  String diagTncLoopbackOk(int len) {
    return 'KISS/AX.25 round-trip identical ($len bytes)';
  }

  @override
  String get diagTncPlatformNo =>
      'TNC links are not supported on this platform';

  @override
  String get diagTncSection => 'TNC (KISS / AX.25)';

  @override
  String get digipeaterTapHint =>
      'Tap a digipeater to open its station details';

  @override
  String get disableClustering => 'Disable clustering';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get displayCat => 'Display';

  @override
  String get displayCatDesc => 'Coords · Theme';

  @override
  String get displayInfo => 'Station info';

  @override
  String get displaySettings => 'Display settings';

  @override
  String get displaySettings2 => 'Display settings';

  @override
  String distKm(Object d) {
    return '$d km';
  }

  @override
  String get distance => 'Distance';

  @override
  String distanceBearing(String distance, String bearing) {
    return '$distance km away · Bearing $bearing°';
  }

  @override
  String get domesticMaps => 'China maps';

  @override
  String get donateAlipay => 'Alipay donation';

  @override
  String get donateAlipayDesc => 'Contact the author for the donation QR code';

  @override
  String get donateWechat => 'WeChat donation';

  @override
  String get donateWechatDesc =>
      'Long-press to save the QR code · tap to enlarge';

  @override
  String get done => 'Done';

  @override
  String get download => 'Download';

  @override
  String get downloadAgain => 'Download package again';

  @override
  String get downloadAndInstall => 'Download & install';

  @override
  String get downloadComplete => 'Download complete';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String downloadHttpError(int code) {
    return 'Download failed: HTTP $code';
  }

  @override
  String get downloadInstaller => 'Download installer';

  @override
  String get downloadNow => 'Download now';

  @override
  String downloadProgress(Object p) {
    return 'Downloading $p%';
  }

  @override
  String get downloadReady => 'Download installation package';

  @override
  String get downloadUpdate => 'Download update';

  @override
  String get downloadUpdateTip => 'Download the update and open it';

  @override
  String downloadedBytes(String received, String total) {
    return 'Downloaded $received / $total';
  }

  @override
  String get downloading => 'Downloading';

  @override
  String get editTrackGroup => 'Edit track group';

  @override
  String get eggBg2hcb => 'Life is all meow-meow and mimi~';

  @override
  String get eggBg7lmw => 'Quiet as ever...';

  @override
  String get eggBg7lzq => 'Hey, what are you doing~';

  @override
  String get eggBg7osl => 'You have got some nerve';

  @override
  String get eggBg7pgw => 'Seriously?';

  @override
  String get emergency => 'Emergency';

  @override
  String get enableClustering => 'Enable clustering';

  @override
  String get enterCallsign => 'Please enter your callsign';

  @override
  String get enterMessage => 'Type a message';

  @override
  String get enterValidCall => 'Please enter a valid callsign';

  @override
  String get errIntervalInt => 'Interval must be an integer of at least 5 s';

  @override
  String get errMinSpeedInt => 'Minimum speed must be an integer >= 1';

  @override
  String get errTierDuplicate =>
      'That speed tier already exists; thresholds must be unique';

  @override
  String get errorLabel => 'Error';

  @override
  String everyNSeconds(String sec) {
    return 'Every $sec s';
  }

  @override
  String get export => 'Export';

  @override
  String get exportAdif => 'Export ADIF';

  @override
  String get exportAdifDesc =>
      'Export conversations as an ADIF log file, importable into Log4OM, N3FJP and similar';

  @override
  String get favorite => 'Favorite';

  @override
  String get favoriteStations => 'Favorite stations';

  @override
  String get favorites => 'Favorites / Manual';

  @override
  String get featureAutoConnect => 'Auto-connect';

  @override
  String get featureAutoConnectDesc =>
      'Automatically connects to a public server and stays online in the background';

  @override
  String get featureBeacon => 'Beaconing';

  @override
  String get featureBeaconDesc =>
      'Custom content, rate, and symbol with APRS-standard formatting';

  @override
  String get featureFmo => 'FMO stations';

  @override
  String get featureFmoDesc =>
      'Automatically detects FMO data and shows structured details';

  @override
  String get featureGps => 'GPS positioning';

  @override
  String get featureGpsDesc =>
      'Native Android location, no Google services required';

  @override
  String get featureLayerFilter => 'Layer filter';

  @override
  String get featureLayerFilterDesc =>
      'Filter: mobile, fixed, digipeater, weather, FMO';

  @override
  String get featureLiveMap => 'Online map';

  @override
  String get featureLiveMapDesc =>
      'GCJ-02 coordinates with smooth zooming and panning';

  @override
  String get featureMsg => 'Messages';

  @override
  String get featureMsgDesc =>
      'Feed + conversation views with Unicode text and auto-reply support';

  @override
  String get features => 'Features';

  @override
  String get feedMode => 'Feed';

  @override
  String get feedback => 'Feedback';

  @override
  String get fillPasscode => 'Enter Passcode';

  @override
  String get filter => 'Range filter';

  @override
  String get filterCenterFollows => 'Follow my location for filter center';

  @override
  String get filterRadius => 'Radius (km)';

  @override
  String get filterRule => 'Filter rule';

  @override
  String get filterSaved => 'Filter saved and applied';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · Radius $radius km';
  }

  @override
  String get filters => 'Filters';

  @override
  String get finish => 'Finish & Connect';

  @override
  String get fitAll => 'Fit all';

  @override
  String get fixed => 'Fixed';

  @override
  String get fmo => 'FMO';

  @override
  String get fmoInfo => 'FMO info';

  @override
  String get followMe => 'Follow me';

  @override
  String get forwardingPath => 'Path';

  @override
  String foundStations(Object count, Object q) {
    return 'Found $count stations matching \"$q\"';
  }

  @override
  String fullCallsign(String call) {
    return 'Full callsign: $call';
  }

  @override
  String get garminAutoFilled => 'Share link filled in automatically';

  @override
  String get garminBadUrl =>
      'That is not a LiveTrack link. Paste the full share URL (with /session/…/token/…)';

  @override
  String get garminCardSubtitle =>
      'Pull your Garmin watch activity in and beacon it';

  @override
  String get garminCardTitle => 'Garmin LiveTrack';

  @override
  String garminError(Object error) {
    return 'Fetch failed: $error';
  }

  @override
  String get garminHowTo =>
      'How to get the link: in the Garmin Connect app open the activity → Share → pick \"APRSlocus\" (the app registers a system share target) and the link lands here and starts tracking; or copy the link and paste it above.';

  @override
  String get garminLinkOk => 'Link is valid';

  @override
  String get garminNoPoints =>
      'No points yet — the activity may have just started, or the link has expired.';

  @override
  String get garminNotStarted => 'Not tracking';

  @override
  String get garminOpen => 'Open settings';

  @override
  String get garminPaste => 'Paste from clipboard';

  @override
  String get garminRunning => 'Tracking';

  @override
  String get garminShareNoLink =>
      'No Garmin LiveTrack link found in what was shared';

  @override
  String get garminSharedToast => 'Garmin share link received';

  @override
  String get garminStart => 'Start tracking';

  @override
  String garminStats(Object n, Object t) {
    return '$n points forwarded · last update $t';
  }

  @override
  String get garminStop => 'Stop tracking';

  @override
  String get garminUrlHint => 'livetrack.garmin.com/session/…/token/…';

  @override
  String get garminUrlLabel => 'Share link';

  @override
  String get garminWebUnsupported =>
      'Not available on the web build (browser CORS); use the Android or Windows build';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get getLocation => 'Get location';

  @override
  String get goSettings => 'Settings';

  @override
  String get gotIt => 'Got it';

  @override
  String get gpsLocating => 'Acquiring GPS location…';

  @override
  String get gpsStatus => 'GPS status';

  @override
  String get greetAfternoon => 'Good afternoon, ';

  @override
  String get greetEvening => 'Good evening, ';

  @override
  String get greetMorning => 'Good morning, ';

  @override
  String get greetNight => 'Hello, ';

  @override
  String get greetNoon => 'Good noon, ';

  @override
  String get grid => 'Grid';

  @override
  String get gridFormat => 'Grid format';

  @override
  String gridValue(String grid) {
    return 'Grid $grid';
  }

  @override
  String groupBubble(String name) {
    return 'Group · $name';
  }

  @override
  String groupCallsignLine(String call) {
    return 'Group callsign: $call';
  }

  @override
  String groupCallsignValue(String call) {
    return 'Group callsign: $call';
  }

  @override
  String get groupChat => 'Group chat';

  @override
  String get groupChatExplain =>
      'Group chats broadcast to a group callsign so every member can receive them. A group callsign is generated automatically and invitations are sent to the members you select.';

  @override
  String get groupChatLabel => 'Group chats';

  @override
  String get groupChatShort => 'Chat';

  @override
  String groupChatTitle(Object name) {
    return 'Group · $name';
  }

  @override
  String groupInviteAccepted(String name) {
    return 'Joined $name';
  }

  @override
  String groupInviteFrom(String from) {
    return '$from invited you to a group chat';
  }

  @override
  String groupInviteRejected(String name) {
    return 'Declined invitation to $name';
  }

  @override
  String get groupInviteTitle => 'Group chat invitation';

  @override
  String get groupNameHint => 'Enter group name';

  @override
  String groupNameValue(String name) {
    return 'Group: $name';
  }

  @override
  String get groupNotFound => 'Group chat not found';

  @override
  String get groupOwner => 'Owner';

  @override
  String get groupShortLabel => 'Group';

  @override
  String get groupTracking => 'Group tracking';

  @override
  String get groupTrackingHint =>
      'Group callsigns you care about and track them on a big map (caravan / friends). Landscape friendly.';

  @override
  String grpInviteBody(String from, String name) {
    return '$from invited you to “$name”';
  }

  @override
  String grpInviteSent(int n) {
    return 'Invite sent to $n member(s)';
  }

  @override
  String get grpInviteTitle => 'Group invite';

  @override
  String get grpNameInvalid =>
      'Group name cannot be empty or contain a colon or newline';

  @override
  String grpNameTooLong(int max) {
    return 'Group name is limited to $max characters (longer makes the invite exceed the APRS message limit)';
  }

  @override
  String get grpSelfPending => 'Waiting for the owner';

  @override
  String grpSysDeclined(String call) {
    return '$call declined the invite';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call asked to join';
  }

  @override
  String grpSysJoined(String call) {
    return '$call joined the group';
  }

  @override
  String grpSysLeft(String call) {
    return '$call left the group';
  }

  @override
  String get guideAudioBody =>
      'Send and receive AFSK frames through the audio output: pick the device, set volume and gain, and use the test tone before connecting.';

  @override
  String get guideAudioTitle => 'Sound-card TNC';

  @override
  String get guideBackupBody =>
      'Export a settings file and restore it in one tap on a new device. Map tiles and the translation cache are not included.';

  @override
  String get guideBackupTitle => 'Backup & restore';

  @override
  String get guideDeviceBody =>
      'Choose where data comes from (APRS-IS / TNC / sound card) and which link transmits. Pair a Bluetooth TNC in the device sub-page first.';

  @override
  String get guideDeviceTitle => 'Devices & data sources';

  @override
  String get guideExportAdifBody =>
      'Write the stations you received into an ADIF file for your logging software, with an optional time range and mode.';

  @override
  String get guideExportAdifTitle => 'Export ADIF';

  @override
  String get guideGotIt => 'Got it';

  @override
  String get guideHomeBody =>
      'Tap a station for its track and details; the bottom button sends your position (connect first).';

  @override
  String get guideHomeTitle => 'Home · map & stations';

  @override
  String get guideImmersiveBody =>
      'Full-screen station view: pinch to zoom, drag to pan, “follow me” at the bottom-left, back arrow at the top-left.';

  @override
  String get guideImmersiveTitle => 'Immersive map';

  @override
  String get guideLogBody =>
      'Every packet and link event is recorded here — the first place to look when something is wrong. Copy the whole log from the top-right.';

  @override
  String get guideLogTitle => 'System log';

  @override
  String get guideMessagesBody =>
      'Type a callsign to start a chat; the top-right menu creates groups and sends bulletins. No replies? Check that you are connected.';

  @override
  String get guideMessagesTitle => 'Messages';

  @override
  String get guideMoreInSettings =>
      'You can reopen this later under Settings → Show all feature guides again';

  @override
  String get guideOfflineMapBody =>
      'Select an area and download its tiles so the map keeps working without network. You can pause and resume.';

  @override
  String get guideOfflineMapTitle => 'Offline maps';

  @override
  String get guidePacketsBody =>
      'The raw received and sent frames, useful for checking how a packet was parsed. Tap a row for the full text.';

  @override
  String get guidePacketsTitle => 'Packets';

  @override
  String get guidePkwdwplBody =>
      'Drive a PKWDWPL interface over a serial port: choose the port and baud rate; it then handles transmission.';

  @override
  String get guidePkwdwplTitle => 'PKWDWPL interface';

  @override
  String get guideResetButton => 'Show again';

  @override
  String get guideResetConfirm =>
      'This clears the “already seen” record so the tip card appears once more on each page.';

  @override
  String get guideResetDone => 'Feature guides reset';

  @override
  String get guideResetRow => 'Show all feature guides again';

  @override
  String get guideResetTitle => 'Show all feature guides again?';

  @override
  String get guideSettingsBody =>
      'Eight categories: radio, beacon, connection, display, devices, data, advanced, update. Changes take effect immediately.';

  @override
  String get guideSettingsTitle => 'Settings';

  @override
  String get guideShowAgain => 'Show this guide again';

  @override
  String get guideStationsBody =>
      'Every station you receive is listed here — search, sort and filter by distance. The list and the map share one filter.';

  @override
  String get guideStationsTitle => 'Station list';

  @override
  String get guideThemeBody =>
      'Change colours, background image, interface material and scale — applied immediately so you can compare on the spot.';

  @override
  String get guideThemeTitle => 'Theme & interface';

  @override
  String get guideTitle => 'Feature guide';

  @override
  String get guideTncDeviceBody =>
      'Scan and pair your Bluetooth TNC, then pick it as the data source on the links page.';

  @override
  String get guideTncDeviceTitle => 'Bluetooth TNC';

  @override
  String get guideTrackHistoryBody =>
      'Replay a station’s route for a given day and drag the timeline to go through it leg by leg.';

  @override
  String get guideTrackHistoryTitle => 'Track replay';

  @override
  String get guideTranslateBody =>
      'Set the target language and the API used to translate chats. Without an API nothing is translated; this page explains what is needed.';

  @override
  String get guideTranslateTitle => 'Translation';

  @override
  String get hamAir =>
      'Poor air quality: wear a mask outdoors and limit exertion; pollution films on antenna insulators add leakage noise, so clean the antenna afterwards';

  @override
  String get hamCold =>
      'Cold / snow: Li-ion capacity drops — carry spare batteries kept warm; watch SWR if ice forms on antennas';

  @override
  String hamDew(String d) {
    return 'Dew point spread only $d℃ — air is near saturation: gear and feedlines may condense moisture; let equipment warm up and dry before powering on to avoid shorts';
  }

  @override
  String get hamDust =>
      'Dust storm: fine sand in connectors and insulators causes leakage and noise — use dust caps; dry friction builds static, so ensure a good ground bleed';

  @override
  String get hamExtreme =>
      'Torrential/extreme rain: watch for flash floods, standing water and rockfall — never set up on riverbanks or low ground; add a drip loop where the feedline enters the wall';

  @override
  String hamFog(String v) {
    return 'Low visibility ($v km): drive carefully; fog can create ducts — try distant VHF/UHF contacts';
  }

  @override
  String get hamFrost =>
      'Below 0℃: lithium battery capacity drops sharply — keep spares warm in a pocket; guard against frostbite on hands and face, carry hand warmers';

  @override
  String hamGale(String w) {
    return 'Wind force $w: do NOT climb towers or masts! Lower or lay down Yagis and long wires, and check guy ropes, anchors and mast stays';
  }

  @override
  String get hamGood =>
      'Great weather for operating! Try repeaters / simplex on VHF-UHF; HF ionosphere shifts in the evening';

  @override
  String get hamGrayLine =>
      'You are in the sunrise/sunset grey line: 20/40m HF propagation peaks now — the golden window for long-haul DX';

  @override
  String get hamHeat2 =>
      'Heat makes PAs and PSUs derate: lower power, shorten continuous transmissions and make sure there is proper ventilation';

  @override
  String hamHighPressure(String p) {
    return 'High, steady pressure ($p hPa): inversions form easily and VHF/UHF tropospheric ducting is possible — try beyond-line-of-sight direct or repeater contacts';
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
  String get hamIce =>
      'Ice on antennas and feedlines raises SWR and adds ice loading: do not force full power, first check guy tension and wait until ice melts before normal operation';

  @override
  String get hamLess => 'Collapse';

  @override
  String get hamLevelDanger => 'Safety';

  @override
  String get hamLevelGood => 'Propagation';

  @override
  String get hamLevelTip => 'Tip';

  @override
  String get hamLevelWarn => 'Caution';

  @override
  String hamLowPressure(String p) {
    return 'Low pressure ($p hPa): weather is becoming unsettled — for long field sessions keep an escape route and watch nearby warnings';
  }

  @override
  String hamMore(String n) {
    return 'Show all $n tips';
  }

  @override
  String get hamNight =>
      'D-layer fades at night: 80/40m absorption drops with lower noise — great for regional and nighttime long-distance work';

  @override
  String get hamNoData =>
      'Once weather is loaded, tips on antenna setup, operating and lightning safety will appear';

  @override
  String get hamRain =>
      'Precipitation: bring rain covers / dry boxes, seal connectors with tape or heat-shrink, keep feed lines drained';

  @override
  String get hamRainFade =>
      'Heavier rain causes rain fade above 1.2GHz: for microwave and EME work, drop to a lower band or wait for the rain to ease';

  @override
  String get hamShower =>
      'Showers come and go quickly: bring a rain cover, watch the cloud movement, and stop transmitting before removing the feedline';

  @override
  String get hamStorm1 =>
      'Thunderstorm: do NOT set up or operate antennas outdoors! Disconnect feed lines to avoid lightning surge damage';

  @override
  String get hamStorm2 =>
      'If already set up, take it down promptly; switch to indoor repeater / HF listening and keep gear dry';

  @override
  String get hamStorm3 =>
      'Lightning approaching: disconnect the antenna feedline from your rig, move it outdoors to a ground rod to bleed static, switch off and unplug mains power so surges cannot enter via AC or LAN; do not use outdoor antennas or corded phones';

  @override
  String get hamStorm4 =>
      'Static crashes (QRN) surge around thunderstorms and HF noise floor rises; wait about 30 minutes after lightning stops before raising antennas and transmitting again';

  @override
  String get hamTitle => 'Ham radio tips';

  @override
  String hamUV(String u) {
    return 'UV index $u (high): protect yourself from sunburn during field work — long exposure also ages coax jackets and cable ties quickly';
  }

  @override
  String hamWind(String w) {
    return 'Wind $w: guy and secure antennas firmly; lower beams / long wires when packing up';
  }

  @override
  String hamWindExtra(String w) {
    return 'Wind $w: still guy the antenna and stay safe in the field';
  }

  @override
  String get headingUp => 'Heading up';

  @override
  String get heatmap => 'Station heatmap';

  @override
  String get heatmapHint => 'Show station density heatmap when zoomed out';

  @override
  String get hfAIndex => 'A index';

  @override
  String get hfAurora => 'Aurora';

  @override
  String get hfBand => 'Band';

  @override
  String get hfDay => 'Day';

  @override
  String get hfEs => 'Es (sporadic E)';

  @override
  String get hfF2 => 'F2 layer';

  @override
  String get hfGeomag => 'Geomag';

  @override
  String get hfKp => 'Kp index';

  @override
  String get hfMuf => 'MUF';

  @override
  String get hfNight => 'Night';

  @override
  String get hfNoData => 'No HF data yet — it loads automatically when online';

  @override
  String get hfNoise => 'Noise';

  @override
  String get hfNow => 'Now';

  @override
  String get hfPowered =>
      'Propagation data by hamqsl.com (N0NBH) · global average, not local measurement';

  @override
  String get hfQClosed => 'Closed';

  @override
  String get hfQFair => 'Fair';

  @override
  String get hfQGood => 'Good';

  @override
  String get hfQPoor => 'Poor';

  @override
  String get hfSfi => 'Solar flux';

  @override
  String get hfSixMeter => '6m band';

  @override
  String get hfSolarWind => 'Solar wind';

  @override
  String get hfSunspots => 'Sunspots';

  @override
  String hfTipBandGood(String b) {
    return '$b is open: favour this band for calling right now';
  }

  @override
  String hfTipBandPoor(String b) {
    return '$b is poor: try another band, or wait for the sunrise/sunset gray line';
  }

  @override
  String get hfTipGeomagActive =>
      'Geomagnetic field is unsettled: high-latitude HF paths are less stable than usual — allow more calling time for DX';

  @override
  String get hfTipHighNoise =>
      'High noise floor: weak signals are hard to copy — narrow the bandwidth, reduce RF gain, use narrow modes if needed';

  @override
  String get hfTipHighSfi =>
      'Solar activity is high (SFI≥150): daytime 15/12/10m should open for long-distance DX';

  @override
  String get hfTipLowSfi =>
      'Low solar activity (SFI<100): little daytime life on 15/12/10m — favour 40/30/20m';

  @override
  String get hfTipStorm =>
      'Geomagnetic storm (Kp≥5): polar HF paths fade badly and trans-polar DX is largely gone — try lower-latitude paths or local VHF/UHF';

  @override
  String get hfTitle => 'HF propagation';

  @override
  String get hfUnavailable => 'HF propagation service is unavailable';

  @override
  String get hfXray => 'X-ray';

  @override
  String get historyClearAll => 'Clear all track history';

  @override
  String get historyClearAllConfirm =>
      'Clear all track history? This cannot be undone.';

  @override
  String get historyClearDay => 'Delete this day';

  @override
  String get historyCleared => 'Day deleted';

  @override
  String get historyClearedAll => 'All track history cleared';

  @override
  String get historyEmpty =>
      'No track history yet. It is recorded automatically once you start positioning and move.';

  @override
  String get historyFollow => 'Follow';

  @override
  String get historyMaxSpeed => 'Max speed';

  @override
  String get historyMovingTime => 'Moving time';

  @override
  String get historyPause => 'Pause';

  @override
  String get historyPlay => 'Play';

  @override
  String get historyPoints => 'Points';

  @override
  String get historyReplay => 'Replay';

  @override
  String get historyTapDay => 'Tap a day to see the map and replay it';

  @override
  String get historyTotalDistance => 'Total distance';

  @override
  String get historyTracks => 'Track history';

  @override
  String get historyTracksDesc =>
      'Records your own speed and distance by day, saved on this device';

  @override
  String get historyVersions => 'History';

  @override
  String get home => 'Home';

  @override
  String get homeBadgeLabel => 'Badge shown on home';

  @override
  String get homeBadgePickDesc =>
      'Pick one earned badge to keep on your home screen';

  @override
  String get homeBadgePickTitle => 'Choose a badge for home';

  @override
  String honorCriteriaLine(String c) {
    return 'How to earn: $c';
  }

  @override
  String get honorWall => 'Honors';

  @override
  String honoredBadges(String n, String m) {
    return '$n/$m badges unlocked';
  }

  @override
  String hoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get hrCardSubtitle =>
      'Bluetooth heart-rate straps (standard HR service), optionally sent with your beacon';

  @override
  String get hrCardTitle => 'Heart rate';

  @override
  String get hrConflictWithTnc =>
      'That device is used by the TNC / PKWDWPL Bluetooth link; it cannot be the strap too';

  @override
  String get hrConnect => 'Connect';

  @override
  String hrConnected(Object name) {
    return 'Connected to $name';
  }

  @override
  String get hrDisconnect => 'Disconnect';

  @override
  String get hrForTncNote =>
      'Heart rate uses BLE while TNC uses classic Bluetooth, so both can be connected';

  @override
  String get hrForget => 'Forget device';

  @override
  String get hrFromGarmin => 'Heart rate from Garmin LiveTrack (watch)';

  @override
  String get hrIncludeHint =>
      'Adds HR=nn to the position comment (the common APRS convention; third-party maps show it as a comment). With no reading we send nothing rather than HR=0, which receivers would read as \"pulse 0\" instead of \"not measured\".';

  @override
  String get hrIncludeInBeacon => 'Send heart rate in beacon';

  @override
  String hrLineHr(String hr) {
    return 'HR $hr';
  }

  @override
  String get hrNoDevice =>
      'No heart-rate device found. Make sure the strap is broadcasting (most straps start once the electrodes are worn) and is close to the phone.';

  @override
  String get hrNotSupported =>
      'Bluetooth heart rate is not available on this platform (available on Android / iOS)';

  @override
  String get hrScanning => 'Scanning…';

  @override
  String get hrSearch => 'Scan for heart-rate devices';

  @override
  String get hrSourceLabel => 'Heart-rate source';

  @override
  String get hrStopScan => 'Stop scanning';

  @override
  String get hrStrapHint =>
      'Any strap broadcasting the standard Heart Rate service (0x180D) works — Polar H10, Garmin HRM, Magene, Coospo. TNC uses classic Bluetooth and heart rate uses BLE, so the two links do not interfere.';

  @override
  String get hrWaitReading =>
      'Waiting for a reading (make sure the strap is snug)';

  @override
  String get iconDefaultMySymbol => 'Icon · Default (my symbol)';

  @override
  String iconNamed(String name) {
    return 'Icon · $name';
  }

  @override
  String get idleTierDesc =>
      'Speeds below the first moving tier are reported with this tier';

  @override
  String get idleTierNotDeletable => 'The idle tier cannot be deleted';

  @override
  String get igateAllRejected =>
      'RF packets are arriving but all of them were rejected by loop protection: they carry TCPIP*/TCPXX* or a q-construct, meaning they came from the internet, and sending them back would multiply the same packet forever. This is the gateway **working correctly**, not a fault.';

  @override
  String get igateEnable => 'Enable gateway';

  @override
  String get igateHint =>
      'Packets heard on RF are forwarded to APRS-IS, tagged with qAr/qAR and your callsign to mark their origin. Requires both APRS-IS and an RF source (TNC / audio) enabled.';

  @override
  String get igateIsDown =>
      'APRS-IS is not connected, so the gateway has nowhere to relay to. The counters will only start moving once it is up (see the link status card).';

  @override
  String get igateNeedIs =>
      'APRS-IS is not enabled: tick it above, otherwise the gateway has nowhere to relay to.';

  @override
  String get igateNeedRf =>
      'No RF source yet: tick TNC or audio under “Data source” above, otherwise the gateway has nothing to relay from.';

  @override
  String get igateNoRfTraffic =>
      'No packets heard on RF at all: the gateway is fully armed but has nothing to relay. This is not a gateway problem — nothing is reaching the app. Check upstream: radio volume and squelch, antenna, whether anyone is actually transmitting, and the log page for any RF traffic at all.';

  @override
  String get igateResetStats => 'Reset counters';

  @override
  String get igateRfDown =>
      'The RF link is down, so the gateway cannot relay anything right now. If “Heard on RF” stays 0, no packets are arriving at all — check the TNC/audio status on the device page (serial baud, device powered on) before suspecting the gateway.';

  @override
  String get igateStatBlocked => 'Loop-protection rejects';

  @override
  String get igateStatDup => 'Duplicates dropped';

  @override
  String get igateStatRfSeen => 'Heard on RF';

  @override
  String get igateStatToIs => 'Relayed → APRS-IS';

  @override
  String get igateStatToRf => 'Relayed → RF';

  @override
  String get igateSubtitle => 'Relay packets heard on RF into APRS-IS';

  @override
  String get igateTitle => 'Gateway (iGate)';

  @override
  String get igateTwoWay => 'Two-way gateway (forward messages to RF)';

  @override
  String get igateTwoWayHint =>
      'When on, this **transmits on RF**: only point-to-point messages addressed to a station recently heard on RF are forwarded (broadcasts such as positions/weather are not, to avoid filling the channel). When off, RF→IS only.';

  @override
  String get immersiveMap => 'Immersive map';

  @override
  String get immersiveMapTip =>
      'Navigation style: centered on you, heading-up, corner HUD';

  @override
  String get imminent => 'Soon';

  @override
  String get information => 'Info';

  @override
  String get infrastructure => 'Digipeater';

  @override
  String get inject => 'Inject';

  @override
  String get injected => 'Packet injected';

  @override
  String get inputTapHint => 'Tap to type';

  @override
  String get install => 'Install';

  @override
  String get installApk => 'Install APRSlocus';

  @override
  String get installComplete => 'Install complete';

  @override
  String get installNow => 'Install now';

  @override
  String get installPermissionDesc =>
      'APRSlocus is not allowed to install apps.\n\nTap “Settings”, allow this app to install unknown apps, then return and try again.';

  @override
  String get installPermissionTitle => 'Allow app installation';

  @override
  String installSize(Object os, Object size) {
    return '$os package size: $size';
  }

  @override
  String get internationalMaps => 'Global maps';

  @override
  String get intervalLabel => 'Interval';

  @override
  String get intervalSeconds => 'Report interval (s)';

  @override
  String get invalidCoords => 'Enter valid latitude, longitude, and radius';

  @override
  String get invalidLatLng => 'Enter valid latitude and longitude';

  @override
  String get invalidResponseData => 'Invalid response format';

  @override
  String get invite => 'Invite';

  @override
  String get inviteMembers => 'Invite members';

  @override
  String get inviteMembersHint => 'Tap “Invite members” below to add people';

  @override
  String inviteMembersTo(String name) {
    return 'Invite members to $name';
  }

  @override
  String inviteSent(String call) {
    return 'Invitation sent to $call';
  }

  @override
  String get invited => 'Invited';

  @override
  String get iosFeatureUnsupported =>
      'iOS does not allow classic Bluetooth / USB serial links (MFi accessories only), so this cannot be enabled; use APRS-IS over the network instead.';

  @override
  String get irreversibleKeepSettings =>
      'This cannot be undone. Connection settings and callsign will be kept.';

  @override
  String get issStation => 'ISS';

  @override
  String get kissApplyParams => 'Push parameters';

  @override
  String get kissAutoAck => 'Auto-acknowledge';

  @override
  String get kissAutoAckTip =>
      'When off, incoming messages are not acknowledged — keeps the channel quieter';

  @override
  String get kissAutoReconnect => 'Reconnect automatically';

  @override
  String get kissBackToCommand => 'Return to TNC command mode';

  @override
  String get kissBackToCommandTip =>
      'Sends RETURN (0x0F). Most KISS TNCs stop forwarding until the link is restarted';

  @override
  String get kissChannel => 'Channel / KISS port';

  @override
  String get kissChannelTip =>
      'Only multi-channel TNCs have several ports; keep 0 for single-channel radios';

  @override
  String get kissFullDuplex => 'Full duplex';

  @override
  String get kissFullDuplexTip =>
      'KISS FULLDUPLEX — leave off for ordinary radios (simultaneous TX/RX interferes)';

  @override
  String get kissHardwareCmd => 'Vendor command';

  @override
  String get kissHardwareTip =>
      'KISS SETHARDWARE (0x06), vendor-specific; -1 means do not send';

  @override
  String get kissHardwareVal => 'Value';

  @override
  String get kissMaxFrame => 'Max frame size (bytes)';

  @override
  String get kissMaxFrameTip =>
      'Longer packets are not sent at all (at 1200 baud an AX.25 frame is ~330 bytes)';

  @override
  String get kissNeedConnected => 'Connect the TNC first';

  @override
  String get kissParamsSent => 'KISS parameters sent';

  @override
  String get kissParamsSubtitle =>
      'Link-layer settings pushed straight to the TNC';

  @override
  String get kissParamsTitle => 'KISS parameters';

  @override
  String get kissPersistence => 'Persistence';

  @override
  String get kissPersistenceTip =>
      'KISS PERSISTENCE, 0–255 — lower is more polite and avoids collisions on a shared channel';

  @override
  String get kissRfBeacon => 'Allow RF beaconing';

  @override
  String get kissRfBeaconTip =>
      'Only then will positions be transmitted on air. Transmitting requires your own licence and callsign';

  @override
  String get kissRfPath => 'RF digipeater path';

  @override
  String get kissRfPathTip =>
      'Digipeaters used on air, e.g. WIDE1-1,WIDE2-1; leave empty for none';

  @override
  String get kissSlotTime => 'Slot time (ms)';

  @override
  String get kissSlotTimeTip =>
      'KISS SLOTTIME in 10 ms units — works with persistence to pace channel access';

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
  String get labDesc =>
      'Lab features are experimental and may affect usability. Portrait orientation is locked by default; enable this to allow landscape.';

  @override
  String get langNameAr => 'Arabic';

  @override
  String get langNameDe => 'German';

  @override
  String get langNameEn => 'English';

  @override
  String get langNameEs => 'Spanish';

  @override
  String get langNameFr => 'French';

  @override
  String get langNameId => 'Indonesian';

  @override
  String get langNameIt => 'Italian';

  @override
  String get langNameJa => 'Japanese';

  @override
  String get langNameKo => 'Korean';

  @override
  String get langNamePt => 'Portuguese';

  @override
  String get langNameRu => 'Russian';

  @override
  String get langNameTh => 'Thai';

  @override
  String get langNameVi => 'Vietnamese';

  @override
  String get langNameZh => 'Chinese (Simplified)';

  @override
  String get langNameZhTw => 'Chinese (Traditional)';

  @override
  String get language => 'Language';

  @override
  String get languageEn => 'English';

  @override
  String get languageEs => 'Spanish';

  @override
  String get languageId => 'Bahasa Indonesia';

  @override
  String get languageJa => '日本語';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get languageZh => '中文';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get lastSeen => 'Last heard';

  @override
  String get latestVersion => 'You are up to date';

  @override
  String get latestVersionLabel => 'Latest version';

  @override
  String get latitude => 'Latitude';

  @override
  String get latitudeHint => 'Latitude 39.9042';

  @override
  String get layerFilter => 'Layers';

  @override
  String get leave => 'Leave';

  @override
  String get leaveAction => 'Leave';

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
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseNotice => 'GNU GPL v3 · Copyright © BG7LZQ';

  @override
  String get licenseSection => 'License';

  @override
  String get licenseStatement =>
      'This software is released under the GNU GPL v3. You may run, study, modify, and redistribute it under the terms of the license; modified and redistributed versions must comply with the applicable GPL v3 requirements. This software is provided without warranty.';

  @override
  String get licenseText => 'View license';

  @override
  String get linkNotConnected => 'Not connected';

  @override
  String get linkOpenFailed => 'Unable to open link';

  @override
  String get linkTapForSettings => 'Tap to open connection settings';

  @override
  String get loadingVectorMap => 'Loading vector map…';

  @override
  String get locModeGps => 'GPS only';

  @override
  String get locModeGpsDesc => 'Satellite only, saves battery';

  @override
  String get locModeGpsNetwork => 'GPS + Network';

  @override
  String get locModeGpsNetworkDesc =>
      'Network is a fallback only (when GPS goes stale); coarse fixes are never written to the track';

  @override
  String get locModeNetHint =>
      'Cell and Wi-Fi fixes can be hundreds of metres off. So that the \"me\" marker does not jump around, they are used only after GPS has been stale for 5 minutes; coarse fixes are never written to the track or history, and never trigger an automatic report.';

  @override
  String get locModeNetwork => 'Network only';

  @override
  String get locModeNetworkDesc =>
      'Cell / Wi-Fi only, accurate to a few hundred metres; most power-saving, for devices without GPS';

  @override
  String get locModeNetworkHint =>
      'In network-only mode the fix comes from cell / Wi-Fi only: it can be hundreds of metres off and is **never** written to the track or history. It will not auto-beacon unless you enable “force auto-beacon on coarse fixes”.';

  @override
  String get localPackageExists => 'A downloaded package is already available';

  @override
  String localRepoVersion(Object latest, Object local) {
    return 'Local v$local · Latest repository v$latest';
  }

  @override
  String get locateMe => 'Locate';

  @override
  String get location => 'Location';

  @override
  String get locationCoarse => 'Network fix (coarse)';

  @override
  String get locationFailed => 'Location failed';

  @override
  String get locationFixed => 'Location acquired';

  @override
  String get locationGarmin => 'Garmin LiveTrack';

  @override
  String get locationInfo => 'Location';

  @override
  String locationInitError(String error) {
    return 'Location initialization failed: $error';
  }

  @override
  String get locationMode => 'Location mode';

  @override
  String get locationNotFixed => 'Not located';

  @override
  String get locationPermission => 'Grant location permission…';

  @override
  String get locationSource => 'Location source';

  @override
  String get locationStatus => 'Location status';

  @override
  String get locationStill => 'Stationary';

  @override
  String get locationStopped => 'Location stopped';

  @override
  String locationStreamError(String error) {
    return 'Location stream error: $error';
  }

  @override
  String get logout => 'Exit';

  @override
  String get logs => 'Logs';

  @override
  String get longitude => 'Longitude';

  @override
  String get longitudeHint => 'Longitude 116.4074';

  @override
  String get lookupAprsFi => 'aprs.fi position';

  @override
  String get lookupPasscode => 'Look up your Passcode →';

  @override
  String get lookupQrz => 'QRZ callsign';

  @override
  String get manage => 'Manage';

  @override
  String get manageContacts => 'Manage contacts';

  @override
  String get management => 'Manage';

  @override
  String get manual => 'Manual';

  @override
  String get manualBeacon => 'Beacon now';

  @override
  String get manualCallsign => 'Enter callsign manually';

  @override
  String get manualCallsignHint => 'Enter callsign manually';

  @override
  String get manualCoordinates => 'Enter coordinates manually';

  @override
  String get manualInject => 'Inject raw APRS packet';

  @override
  String get manualLocation => 'Manual location';

  @override
  String get manualLocationHelp =>
      'If automatic location is unavailable, enter coordinates or pick a point on the map for beaconing and distance calculations.';

  @override
  String get manualStations => 'Manual stations';

  @override
  String get map => 'Map';

  @override
  String mapDefaultCoord(int level) {
    return 'Beijing · Zoom $level';
  }

  @override
  String get mapHelpIntro =>
      'No stations in view. Possible reasons: not connected to APRS-IS, small receive range, or no active stations nearby.';

  @override
  String get mapHelpLayer =>
      'Layers & style: top-right buttons filter station types / switch basemap';

  @override
  String get mapHelpLocate =>
      'Locate: tap “Locate me” (bottom-right) to return to your position';

  @override
  String get mapHelpMove =>
      'Move / zoom: drag to pan, pinch or scroll-wheel to zoom';

  @override
  String get mapHelpSearch =>
      'Search: type a callsign in the top search box to jump to it';

  @override
  String get mapHelpStation =>
      'Stations: tap a marker to select & center, double-tap for details';

  @override
  String get mapHelpTitle => 'Map help';

  @override
  String get mapHome => 'Recenter';

  @override
  String get mapLayers => 'Layers';

  @override
  String get mapLocate => 'Locate';

  @override
  String get mapMenu => 'Map menu';

  @override
  String get mapPickDesc => 'Tap the map to set your position';

  @override
  String get mapPickMode => 'Map position picker';

  @override
  String get mapPickNow => 'Pick on map';

  @override
  String get mapType => 'Map type';

  @override
  String get mapTypeAmap => 'AMap';

  @override
  String get mapTypeAmapSatellite => 'AMap Satellite';

  @override
  String get mapTypeCarto => 'Carto Light';

  @override
  String get mapTypeCartoDark => 'Carto Dark';

  @override
  String get mapTypeCartoPositron => 'Carto Positron (light vector)';

  @override
  String get mapTypeCartoVoyager => 'Carto Voyager';

  @override
  String get mapTypeDesc =>
      '\"Map 2.0 (vector)\" renders vectors on-device for lower data use and sharp zooming; raster sources use online tiles, so quality depends on the network.';

  @override
  String get mapTypeEsriSat => 'Esri Imagery';

  @override
  String get mapTypeEsriStreet => 'Esri Streets';

  @override
  String get mapTypeOpenTopo => 'OpenTopo Terrain';

  @override
  String get mapTypeOsm => 'OSM Standard';

  @override
  String get mapTypeOsmHot => 'OSM Humanitarian';

  @override
  String get mapTypeTitle => 'Map type';

  @override
  String get mapTypeVector => 'Vector map';

  @override
  String get mapZoomIn => 'Zoom in';

  @override
  String get mapZoomOut => 'Zoom out';

  @override
  String get maxPackets => 'Packet history limit';

  @override
  String get maxPacketsTip =>
      'How many packets to keep on the packets page (default 2000; higher uses more memory)';

  @override
  String get maxSpeedTiers => 'Up to 5 speed tiers';

  @override
  String get maxStations => 'Max stations';

  @override
  String get maxStationsTip =>
      'Maximum stations kept in memory (unlimited by default; increase as needed)';

  @override
  String get maxTrackPts => 'Track point limit';

  @override
  String get maxTrackPtsTip =>
      'Track points kept per station (default 300; decides how far back a movement track can reach; a point is only stored after 20 m of movement)';

  @override
  String get meLabel => 'Me';

  @override
  String get memberBlocked => 'Blocked';

  @override
  String memberCount(int count) {
    return '$count members';
  }

  @override
  String memberCountTap(int count) {
    return '$count members · Tap to view';
  }

  @override
  String get memberDeclined => 'Declined';

  @override
  String get memberJoined => 'Joined';

  @override
  String get memberLeft => 'Left';

  @override
  String memberOnlineCount(int members, int online) {
    return '$members members · $online online';
  }

  @override
  String get memberPending => 'Pending';

  @override
  String get memberTimeout => 'Timed out';

  @override
  String get message => 'Message';

  @override
  String get messageCountLabel => 'Messages';

  @override
  String get messageFeed => 'Message feed';

  @override
  String get messageSent => 'Message sent';

  @override
  String messageTotal(int count) {
    return '$count messages';
  }

  @override
  String get messages => 'Messages';

  @override
  String get metricUnits => 'Metric (km/h, m)';

  @override
  String get minSpeedKmh => 'Minimum speed (km/h)';

  @override
  String minutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get mobile => 'Mobile';

  @override
  String get moreSymbols => 'More symbols';

  @override
  String get moving => 'Moving';

  @override
  String movingCount(Object count) {
    return '$count moving';
  }

  @override
  String movingWithSpeed(String speed) {
    return 'Moving · $speed';
  }

  @override
  String get msgBlockedTooLong =>
      'Send blocked: packet exceeds the APRS-IS limit';

  @override
  String get msgHistory => 'Message history';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 chars · $bytes/512 bytes total';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return 'The packet is $bytes bytes, over the 512-byte APRS-IS line limit. The server may drop it entirely (not even the header arrives). Please shorten by about $over bytes.';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return 'This message is $chars characters, over the APRS spec limit of 67. Most clients will still show it, but some clients/gateways truncate or reject it, so the other station may not be able to parse it. Send anyway?';
  }

  @override
  String get msgSendAnyway => 'Send anyway';

  @override
  String get msgSpecLimitHint =>
      'The APRS spec recommends keeping a message under 67 characters: longer text may be truncated or fail to parse in some clients.';

  @override
  String get myBadgesAndAchievements => 'My badges and achievements';

  @override
  String get myCallsign => 'My callsign';

  @override
  String get myLocation => 'My location';

  @override
  String myLocationPanel(Object call) {
    return 'My location · $call';
  }

  @override
  String myLocationSetGrid(String grid) {
    return 'Location set · Grid $grid';
  }

  @override
  String myPositionSet(String grid) {
    return 'My position set, grid $grid';
  }

  @override
  String get myStation => 'My station';

  @override
  String get myStationSettings => 'My station';

  @override
  String get myStationSettingsDesc => 'Callsign · SSID · Symbol · Beaconing';

  @override
  String get mySymbol => 'My symbol';

  @override
  String nItems(String n) {
    return '$n';
  }

  @override
  String nMessages(String n) {
    return '$n';
  }

  @override
  String get nameLabel => 'Name';

  @override
  String get navigate => 'Navigate';

  @override
  String get navigationUnavailable =>
      'No map app is installed and no other map app could be opened';

  @override
  String get nearbyStations => 'Nearby stations';

  @override
  String get newConversation => 'New conversation';

  @override
  String get newConversationDesc => 'Enter a callsign to start a conversation';

  @override
  String get newGroup => 'New group';

  @override
  String get newTrackGroup => 'New track group';

  @override
  String get newVersion => 'New version';

  @override
  String get newVersionFound => 'New version available';

  @override
  String newVersionTitle(String version) {
    return 'New version v$version available';
  }

  @override
  String get next => 'Next';

  @override
  String get nextBeacon => 'Next beacon';

  @override
  String nextBeaconIn(String time) {
    return 'Next beacon $time';
  }

  @override
  String get nextBeaconLabel => 'Next';

  @override
  String get noApkInstaller => 'No APK for this release';

  @override
  String get noContacts => 'No contacts';

  @override
  String get noConversations => 'No conversations yet';

  @override
  String get noCountriesSelected => 'No countries or regions selected';

  @override
  String get noData => 'No data';

  @override
  String get noFixYet => 'No location fix yet; current position is unavailable';

  @override
  String get noGroupMessages => 'No group messages yet';

  @override
  String get noInstaller => 'No package';

  @override
  String noInstallerHistoryHint(String platform) {
    return 'No $platform package for this release. Choose a downloadable version from History.';
  }

  @override
  String get noLogs => 'No logs yet';

  @override
  String get noMatchingPackets => 'No matching packets';

  @override
  String get noMembers => 'No members';

  @override
  String get noMembersSelected => 'No members selected';

  @override
  String get noMessages => 'No messages yet';

  @override
  String get noMessagesHint => 'No messages yet — say hi!';

  @override
  String get noMoreOnlineStations => 'No more online stations';

  @override
  String get noPacketReceived => 'No packets received';

  @override
  String get noPackets => 'No packets yet';

  @override
  String noPositionInfo(Object call) {
    return 'No position information for $call (packet contains no position)';
  }

  @override
  String get noRecipients => 'No recipients selected';

  @override
  String get noReleaseNotes => 'No release notes';

  @override
  String get noSsid => 'No suffix (base callsign)';

  @override
  String get noStationHelp => 'No stations here · tap for help';

  @override
  String get noStationInView => 'No stations here · tap to show all';

  @override
  String get noStations => 'No stations';

  @override
  String get noStationsFiltered => 'No stations match the current filter';

  @override
  String get noStationsFilteredHint =>
      'The filter or receive range is too narrow. Clear the filter to retry; the receive range lives in Settings.';

  @override
  String get noStationsYet =>
      'No station data yet. Connect to APRS-IS to pick members.';

  @override
  String get noUpdateFound => 'You are up to date';

  @override
  String get noVersionsFound => 'No releases found';

  @override
  String get noWindowsInstaller => 'No Windows installer for this release';

  @override
  String get none => 'None';

  @override
  String get nonprofitNote =>
      'Non-profit learning and community project\nDonations only cover server and development costs';

  @override
  String get northUp => 'North up';

  @override
  String get notConnectedAprsServer => 'Not connected to APRS-IS';

  @override
  String get notFound => 'No stations found';

  @override
  String get notLit => 'Not yet';

  @override
  String noticeCached(String ago) {
    return 'Cached · $ago';
  }

  @override
  String get noticeEmpty => 'No announcements yet';

  @override
  String get noticeEntryDesc => 'Latest announcements from the website';

  @override
  String get noticeLoading => 'Loading…';

  @override
  String noticeOfflineCache(String time) {
    return 'Offline copy · $time (updates automatically once online)';
  }

  @override
  String get noticeReadMore => 'Read more';

  @override
  String get noticeTitle => 'Announcements';

  @override
  String get notifAudioConnected => 'Audio link online';

  @override
  String get notifAudioDisconnected => 'Audio link disconnected';

  @override
  String notifBeacon(String v) {
    return 'Beacon $v';
  }

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
  String get notifTncConnected => 'TNC connected';

  @override
  String get notifTncDisconnected => 'TNC disconnected';

  @override
  String get objectType => 'Object';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get offline => 'Offline';

  @override
  String get offlineAreaHint => 'The current view is the area to download';

  @override
  String get offlineCacheDisabled => 'Tile cache unavailable on this platform';

  @override
  String get offlineCacheSwitch => 'Cache map tiles';

  @override
  String get offlineCacheSwitchDesc =>
      'Saves tiles while you browse, so they can be viewed offline later';

  @override
  String get offlineCacheUsage => 'Tile cache';

  @override
  String get offlineCacheUsageDesc =>
      'Cached automatically while browsing; areas can also be downloaded manually';

  @override
  String get offlineCancelDownload => 'Cancel';

  @override
  String get offlineClearCache => 'Clear all tile cache';

  @override
  String get offlineClearCacheConfirm => 'Clear all downloaded map tiles?';

  @override
  String get offlineClearCacheConfirmBody =>
      'Downloaded tiles will be deleted; area records stay and must be downloaded again for offline use.';

  @override
  String get offlineDeleteKeepTiles => 'Delete the record only (keep tiles)';

  @override
  String offlineDeleteRegionConfirm(String name) {
    return 'Delete offline area \"$name\"?';
  }

  @override
  String offlineDeleteTileCount(String n) {
    return 'About $n tiles will be deleted';
  }

  @override
  String get offlineDeleteWithTiles => 'Delete the record and its tiles';

  @override
  String offlineDeletingTiles(String done, String total) {
    return 'Deleting $done/$total';
  }

  @override
  String get offlineDownloadBusy =>
      'Another download is running — wait or cancel it first';

  @override
  String offlineEstimate(String tiles, String size) {
    return 'about $tiles tiles · about $size';
  }

  @override
  String offlineFailedCount(String n) {
    return '$n failed';
  }

  @override
  String get offlineLoading => 'Loading…';

  @override
  String get offlineMap => 'Offline maps';

  @override
  String get offlineMapDesc =>
      'Download map tiles ahead of time so the map works without a network';

  @override
  String get offlineMapFooter =>
      'Tiles stay on this device and are never uploaded; each source keeps its own cache';

  @override
  String get offlineName => 'Name';

  @override
  String get offlineNameHint => 'e.g. Around home';

  @override
  String get offlineNew => 'New area';

  @override
  String get offlineNoRegions => 'No offline areas yet';

  @override
  String get offlineNoRegionsHint =>
      'Tap \"New area\" to download the places you visit often';

  @override
  String get offlineOnlySwitch => 'Offline tiles only';

  @override
  String get offlineOnlySwitchDesc =>
      'Never load tiles from the network — only downloaded/cached ones (saves data)';

  @override
  String get offlineOnlyWarn =>
      '\"Offline tiles only\" is on — parts of the map may be missing';

  @override
  String get offlinePause => 'Pause';

  @override
  String get offlineRegions => 'Offline areas';

  @override
  String get offlineRegionsDesc =>
      'Downloaded areas can be viewed on the map offline';

  @override
  String get offlineResume => 'Resume';

  @override
  String get offlineShort => 'Offline';

  @override
  String get offlineSource => 'Map source';

  @override
  String get offlineStartDownload => 'Start download';

  @override
  String get offlineStatusCanceled => 'Canceled';

  @override
  String get offlineStatusDone => 'Done';

  @override
  String get offlineStatusFailed => 'Failed';

  @override
  String get offlineStatusPaused => 'Paused';

  @override
  String get offlineStatusPending => 'Waiting';

  @override
  String get offlineStatusRunning => 'Downloading';

  @override
  String get offlineSwitchFirst => 'Turn on \"Cache map tiles\" first';

  @override
  String offlineTileProgress(String done, String total) {
    return '$done/$total tiles';
  }

  @override
  String offlineTilesDownloaded(String n) {
    return '$n tiles downloaded';
  }

  @override
  String offlineTooManyTiles(String tiles) {
    return 'Area too large (about $tiles tiles) — narrow it or lower the max zoom';
  }

  @override
  String offlineZoomLevels(String min, String max) {
    return 'zoom $min–$max';
  }

  @override
  String get ok => 'OK';

  @override
  String get online => 'Online';

  @override
  String onlineCount(Object count) {
    return '$count online';
  }

  @override
  String get onlineOnly => 'Online only';

  @override
  String get onlineWindow => 'Online window (minutes)';

  @override
  String get onlineWindowTip =>
      'A station with no report for longer than this is treated as offline (default 5 minutes)';

  @override
  String get onlyWgs84 => 'WGS-84 only';

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
  String get oobeAgreeTitle => 'User Agreement & License';

  @override
  String get oobeBackgroundTip =>
      'Tip: allow APRSlocus to run in the background, disable battery optimization, and allow autostart to keep beaconing active.';

  @override
  String get oobeCallDesc => 'Enter your callsign';

  @override
  String get oobeCallTitle => 'Set callsign';

  @override
  String get oobeDeclineExit => 'Decline and exit';

  @override
  String get oobeFilterDesc =>
      'Tick the countries/regions to receive. Leave all unselected to receive every station with no restriction.';

  @override
  String get oobeFilterTitle => 'Choose receive region';

  @override
  String get oobeGpsFeatureDesc =>
      'Acquire your location and send position beacons to APRS-IS';

  @override
  String get oobeIsFeatureDesc =>
      'Connect to a public server and receive global APRS station data';

  @override
  String get oobeMapFeatureDesc =>
      'Online map tiles with nearby APRS stations and tracks';

  @override
  String get oobeMsgFeatureDesc =>
      'Exchange station messages with auto-reply support';

  @override
  String get oobeNextSteps =>
      'Complete the basic setup in the next few steps. You can change it later in Settings.';

  @override
  String get oobePasscodeMissing => 'Passcode not entered';

  @override
  String get oobePasscodeMissingDesc =>
      'The Passcode is the APRS-IS login verification code for your callsign.\n\nThe default -1 allows an unverified connection, but messages and group chat will not work normally.\n\nLook up the correct Passcode for your callsign at https://aprs.cool/AprsPG.';

  @override
  String get oobeServerDesc =>
      'Connect to receive APRS station data worldwide. The default settings work as-is.';

  @override
  String get oobeServerTitle => 'Connect to APRS-IS server';

  @override
  String get oobeSymbolDesc =>
      'The symbol represents your station type and is sent with position beacons';

  @override
  String get oobeSymbolTitle => 'Choose station symbol';

  @override
  String get oobeWelcomeDesc => 'Start configuring your APRS station';

  @override
  String get oobeWelcomeGps => 'GPS position beaconing';

  @override
  String get oobeWelcomeIs => 'APRS-IS feed';

  @override
  String get oobeWelcomeMsg => 'APRS messages';

  @override
  String get oobeWelcomeRealMap => 'Live map';

  @override
  String get oobeWelcomeTitle => 'Welcome to APRSlocus';

  @override
  String get openContainingFolder => 'Open containing folder';

  @override
  String get openDownload => 'Open download page';

  @override
  String get openDownloadFolder => 'Open downloads folder';

  @override
  String get openDownloads => 'Open downloads folder';

  @override
  String get openFolder => 'Open folder';

  @override
  String get openInBrowser => 'Open in browser';

  @override
  String get openInMap => 'View on map';

  @override
  String get openInstallDir => 'Open install folder';

  @override
  String get openPackageManually => 'Open the package in a file manager';

  @override
  String get openSource => 'Open-source acknowledgements';

  @override
  String orMoveM(String dist) {
    return 'or $dist m';
  }

  @override
  String orTurnDeg(String deg) {
    return 'or $deg°';
  }

  @override
  String get osAmap => 'AMap';

  @override
  String get osAmapDesc => 'Map tile service';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => 'Global APRS data network';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Google cross-platform UI framework';

  @override
  String get osHam => 'Amateur radio';

  @override
  String get osHamDesc => 'Contributions from the APRS amateur radio community';

  @override
  String get ossLicenseSection => 'Open source & license';

  @override
  String get otherType => 'Other';

  @override
  String get ownSourceGarminLive => 'Tracking (phone GPS stepped aside)';

  @override
  String get ownSourceGarminStale => 'Link set, but Garmin has no fresh points';

  @override
  String get ownSourceHrIdle => 'Not connected (tap to connect a strap)';

  @override
  String get ownSourcePhoneGps => 'Phone GPS';

  @override
  String get packageDeleted => 'Package deleted';

  @override
  String packageSize(String platform, String size) {
    return '$platform package size: $size';
  }

  @override
  String get packetConsole => 'Packet console';

  @override
  String packetLimitIs(int bytes) {
    return 'Packet $bytes B · APRS-IS line limit 512 B';
  }

  @override
  String packetLimitRf(int bytes, int max) {
    return 'Packet $bytes B · RF frame limit $max B';
  }

  @override
  String get packetParseHint =>
      'Paste a raw APRS packet, e.g.:\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test station';

  @override
  String get packetParseTest => 'Packet parser test';

  @override
  String packetSendFailed(String err) {
    return 'Not sent: $err';
  }

  @override
  String packetSent(String line) {
    return 'Handed to the link: $line';
  }

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return 'RX $rx · TX $tx · $ppm/min';
  }

  @override
  String get packetTcpipWarning =>
      'Contains TCPIP*: it is stripped on RF (that path belongs to APRS-IS)';

  @override
  String get packets => 'Packets';

  @override
  String packetsPerMinute(int count) {
    return '$count/min';
  }

  @override
  String get packetsReceived => 'RX';

  @override
  String get parseAndApply => 'Parse & apply';

  @override
  String get parsedMode => 'Parsed mode';

  @override
  String get passcode => 'Passcode';

  @override
  String get passcodeImportant => 'Passcode is important';

  @override
  String get passcodeImportantDesc =>
      'A correct Passcode is required to receive group messages and send acknowledgements. -1 can connect, but messaging will not work normally.';

  @override
  String get passcodeLookupHint => 'Enter your callsign, e.g. BV2AAA';

  @override
  String get passcodeMessageWarning =>
      'APRS-IS login passcode. Using -1 prevents normal message send/receive.';

  @override
  String get passcodeTip =>
      'APRS-IS login passcode; generate it online. Use -1 for unverified login';

  @override
  String get passcodeUnverified => 'Passcode not verified';

  @override
  String get passcodeUnverifiedHint => '-1 (unverified)';

  @override
  String get passcodeWarning =>
      'The login passcode may be incorrect; messages may not work';

  @override
  String get pasteAprsPacketHint =>
      'Paste a raw APRS packet, e.g.\\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test';

  @override
  String get phoneBattery => 'Phone battery';

  @override
  String get pickBeaconIconDesc =>
      'Pick a beacon icon · \"Default\" keeps my symbol';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get pickTrackMembers => 'Pick members (check callsigns to track)';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return 'Position set · $lat, $lng · Grid $grid';
  }

  @override
  String get pkwdwplBindSubtitle =>
      'Pick the serial or Bluetooth port that outputs \$PKWDWPL sentences';

  @override
  String get pkwdwplBindTitle => 'Device binding and status';

  @override
  String get pkwdwplDeviceDesc =>
      'Bind the radio port and check waypoint reception';

  @override
  String get pkwdwplDeviceTitle => 'PKWDWPL device';

  @override
  String get pkwdwplErrReadOnly => 'receive-only link cannot transmit';

  @override
  String get pkwdwplLogEmpty => 'No PKWDWPL log yet';

  @override
  String get pkwdwplReadOnly => 'Receive-only · this device transmits nothing';

  @override
  String get pkwdwplRxOnly => 'Receive-only';

  @override
  String get pkwdwplStatIgnored => 'Other NMEA sentences (ignored)';

  @override
  String get pkwdwplStatMismatch => 'Checksum mismatches';

  @override
  String get pkwdwplStatRejected => 'Dropped or invalid sentences';

  @override
  String get pkwdwplStatTitle => 'Waypoint reception';

  @override
  String pkwdwplStats(String rx) {
    return '$rx waypoints received';
  }

  @override
  String get pkwdwplStrictChecksum => 'Strict checksum (drop mismatches)';

  @override
  String get pkwdwplStrictChecksumTip =>
      'Off by default: a mismatch is flagged and logged instead of dropped, because on a local cable it usually means the firmware format differs from the manual. Dropping every sentence would leave the screen empty and make diagnosis much harder.';

  @override
  String get pkwdwplTip =>
      'Set the PC / GPS port output format on the radio to \"\$PKWDWPL\" (usually 4800 8N1). This link is read-only and transmits nothing.';

  @override
  String get platform => 'Platform';

  @override
  String get port => 'Port';

  @override
  String get posAccuracy => 'Position accuracy';

  @override
  String get posSourceIdle => 'Not tracking (location off)';

  @override
  String get posSourceLabel => 'Position source';

  @override
  String get posSourcePrecedence =>
      'Priority when several are available: simulated/manual › Garmin (while the watch has live data) › phone GPS';

  @override
  String posSourceUsing(String src) {
    return 'In use now: $src';
  }

  @override
  String get posSrcGarmin => 'Garmin LiveTrack';

  @override
  String get posSrcNone => 'no fix';

  @override
  String get posSrcPhone => 'phone GPS';

  @override
  String get posSrcSim => 'simulated/manual';

  @override
  String get position => 'Position';

  @override
  String positionBeacon(Object grid) {
    return 'Position beacon · Grid $grid';
  }

  @override
  String positionBeaconDetail(String grid, String detail) {
    return 'Position beacon · Grid $grid · $detail';
  }

  @override
  String get previous => 'Previous';

  @override
  String get projectRepo => 'Repository';

  @override
  String get qqGroup => 'QQ group';

  @override
  String get qqGroupDesc => 'APRSlocus · Feedback and discussion';

  @override
  String get qqSoftwareName => 'APRSlocus';

  @override
  String qrCodeTitle(String title) {
    return '$title QR code';
  }

  @override
  String get qrLoadFailed => 'QR code image failed to load';

  @override
  String get qrSaveWechat => 'Long-press to save · Scan with WeChat to support';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get quickTrackCreate => 'New track group';

  @override
  String get quickTrackHint =>
      'Pick stations you received, or type callsigns — track them on the map directly, no chat group required.';

  @override
  String get quickTrackManualHint => 'Type callsigns, e.g. BG7PGW,BG7LMW';

  @override
  String get quickTrackName => 'Name (optional)';

  @override
  String get quickTrackNeedMembers => 'Pick or type at least one callsign';

  @override
  String get quickTrackNoStations =>
      'No stations received yet — type callsigns below (comma separated)';

  @override
  String get quickTrackPickLabel => 'Choose stations to track';

  @override
  String get quickTrackStart => 'Start tracking';

  @override
  String get quitApp => 'Quit app';

  @override
  String get quitAppDesc =>
      'Quitting stops location reporting and background reception, and ends the process.';

  @override
  String get radioCat => 'Station';

  @override
  String get radioCatDesc => 'Callsign · SSID · Symbol';

  @override
  String get radiusTip =>
      'Receive radius (km); tap “Save & apply filter” to apply';

  @override
  String get range10m => '10 min';

  @override
  String get range1h => '1 h';

  @override
  String get range30m => '30 min';

  @override
  String get range3h => '3 h';

  @override
  String get rangeAll => 'All';

  @override
  String get rangeFilterDesc =>
      'Receive only station packets within the configured range';

  @override
  String get rawMode => 'Raw mode';

  @override
  String get receive => 'Receive';

  @override
  String get receiveCountries => 'Countries';

  @override
  String get receiveCountryDesc =>
      'Receive all stations from a country/region by callsign prefix';

  @override
  String get receiveFilter => 'Callsign filter';

  @override
  String get receiveFilterDesc2 =>
      'In addition to the range filter, receive stations by country/region or exact callsign';

  @override
  String get receiveOthers => 'Other stations';

  @override
  String get receiveOthersDesc =>
      'Receive special stations whose callsigns do not match selected countries';

  @override
  String get recentPackets => 'Recent packets';

  @override
  String get recheck => 'Check again';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get reconnectToApply => 'Reconnect to apply';

  @override
  String get reconnected => 'Reconnected';

  @override
  String get redownload => 'Download again';

  @override
  String get refresh => 'Refresh';

  @override
  String get reject => 'Decline';

  @override
  String get relatedStations => 'Related stations';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get reloadDone => 'Reloaded';

  @override
  String get reloadUi => 'Reload UI';

  @override
  String get relocate => 'Relocate';

  @override
  String get remove => 'Remove';

  @override
  String repoLatestTitle(String version) {
    return 'Latest repository version v$version';
  }

  @override
  String get reselectPoint => 'Pick again';

  @override
  String get resetAll => 'Reset all settings';

  @override
  String get resetAllDesc => 'Factory reset';

  @override
  String get restartWizard => 'Run setup wizard again';

  @override
  String get restartWizardButton => 'Run again';

  @override
  String get restartWizardConfirm =>
      'The first-run wizard will open again so you can reset your callsign, receive area and more.\\nYour current settings are kept; continue using the app after finishing the wizard.';

  @override
  String get restartWizardTitle => 'Run setup wizard again?';

  @override
  String get restoreDefaults => 'Restore defaults';

  @override
  String get retry => 'Retry';

  @override
  String get runInstaller => 'Run installer';

  @override
  String get runNow => 'Run now';

  @override
  String rxOnlyBanner(String arg) {
    return '$arg connected · receive-only (the transmit source is offline)';
  }

  @override
  String get rxTx => 'RX / TX';

  @override
  String get save => 'Save';

  @override
  String get saveAndApply => 'Save & apply filter';

  @override
  String get saveAndTrack => 'Save & track';

  @override
  String get savedLocation => 'Saved location';

  @override
  String get search => 'Search';

  @override
  String get searchCallsign => 'Search callsign…';

  @override
  String get searchHint => 'Search callsign / type / grid / comment…';

  @override
  String get searchPacket => 'Search callsign, dest or raw…';

  @override
  String secondsAgo(int count) {
    return '${count}s ago';
  }

  @override
  String secondsValue(int count) {
    return '$count sec';
  }

  @override
  String get selectAll => 'Select all';

  @override
  String get selectAllOnline => 'Select all online';

  @override
  String get selectConversation => 'Select a conversation to start chatting';

  @override
  String get selectMapType => 'Select map type';

  @override
  String get selectMessageReply => 'Select a message to reply…';

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String selectedRecipients(int count) {
    return '$count selected';
  }

  @override
  String get send => 'Send';

  @override
  String get sendBeacon => 'Send beacon';

  @override
  String sendMessageTo(String call) {
    return 'Message $call…';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return 'Sending to $count: $calls';
  }

  @override
  String get sendTo => 'Send to';

  @override
  String sendToCallHint(String call) {
    return 'Send to $call…';
  }

  @override
  String sendToGroupHint(String group) {
    return 'Send to $group…';
  }

  @override
  String get sender => 'Sender';

  @override
  String get sensorAssist => 'Sensor-assisted positioning';

  @override
  String get sensorAssistDesc =>
      'Uses the accelerometer to tell whether you are really moving and the compass to correct the heading at low speed, for more accurate track points (Android only).';

  @override
  String get server => 'Server';

  @override
  String serverReturned(int code) {
    return 'Server returned $code';
  }

  @override
  String get setStep => 'Step';

  @override
  String get settings => 'Settings';

  @override
  String get settingsBeaconSubtitle => 'Transmit interval & report content';

  @override
  String get settingsChatManageSubtitle => 'Contacts and chat data';

  @override
  String get settingsChatStatsSubtitle => 'Message and contact statistics';

  @override
  String get settingsClearDataSubtitle => 'Delete local records';

  @override
  String get settingsConnStatusSubtitle => 'Connection status and info';

  @override
  String get settingsContribCodeOptimization => 'Code optimization';

  @override
  String get settingsDesc => 'Configure station, location & connection';

  @override
  String get settingsDevSubtitle => 'Debugging and testing';

  @override
  String get settingsDisplayInfoSubtitle => 'My symbol and current position';

  @override
  String get settingsFilterHint =>
      'Only receive station packets within the configured range';

  @override
  String get settingsFilterSubtitle => 'Filter center and radius';

  @override
  String get settingsGeneralSubtitle =>
      'Theme, language and coordinate display';

  @override
  String get settingsLabSubtitle => 'Experimental features';

  @override
  String get settingsLocModeSubtitle => 'Choose location method';

  @override
  String get settingsLocSourceSubtitle => 'Choose position source';

  @override
  String get settingsManualLocHint =>
      'When auto-location is unavailable, enter coordinates manually or pick on the map for beacon reporting and station distance calculation.';

  @override
  String get settingsManualLocSubtitle =>
      'Manual input or map pick when no fix';

  @override
  String get settingsMapSubtitle => 'Map type and display';

  @override
  String get settingsReceivePrefHint =>
      'Besides range filter, receive stations by country/region group or exact callsign';

  @override
  String get settingsReceivePrefSubtitle =>
      'Receive by country/region or callsign';

  @override
  String get settingsServerSubtitle => 'APRS-IS server and passcode';

  @override
  String get settingsStationIdentitySubtitle => 'Callsign, SSID and comment';

  @override
  String get settingsSubtitle => 'Map coordinates & display preferences';

  @override
  String get shareApp => 'Share APRSlocus';

  @override
  String get shareText =>
      'APRSlocus — APRS Tracking & Mapping for amateur radio 📡\nReal-time station tracking, messaging & beaconing. Available on Android & Windows.\nWebsite: https://aprslocus.theez.top/\nDownload: https://github.com/dariondong/APRSLocus/releases';

  @override
  String get shareTextCopied => 'Share text copied, paste it to your friends';

  @override
  String get shareToSystem => 'Share to system';

  @override
  String get shareToSystemDesc => 'WeChat, QQ, SMS, etc.';

  @override
  String get showAll => 'Show all';

  @override
  String get showStations => 'Show stations';

  @override
  String get showTrails => 'Show tracks';

  @override
  String get simData => 'Enable demo data (sample stations/packets)';

  @override
  String get simLocationHint => 'Use a simulated location (no GPS needed)';

  @override
  String get simulatedKeepAlive => 'Simulated location · keep-alive';

  @override
  String get simulatedLocation => 'Simulated location';

  @override
  String get smartBeacon => 'SmartBeacon (by speed)';

  @override
  String get software => 'Software';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortCall => 'Callsign';

  @override
  String get sortDistance => 'Distance';

  @override
  String get sortRecent => 'Recent';

  @override
  String get sortStatus => 'Status';

  @override
  String get sourceMovedHint =>
      'To enable or switch data sources (links), go to Settings → Devices';

  @override
  String get speed => 'Speed';

  @override
  String get speedLabel => 'Speed';

  @override
  String get speedTierDesc =>
      'The faster you move, the more often you report; each tier can have its own interval and icon (blank = my symbol).';

  @override
  String get speedTierRules => 'Speed tiers';

  @override
  String get speedTierShortIntervalWarn =>
      'Intervals under 60 s noticeably increase server load; 60 s or more is recommended.';

  @override
  String get sponsorAuthor => 'Author BG7LZQ';

  @override
  String get sponsorAuthorItems =>
      'Develops and maintains this project in spare time';

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
  String get sponsorGroup => 'STUDENT HAMS';

  @override
  String get sponsorGroupItems => 'Thanks to the group for financial support';

  @override
  String get sponsorMethods => 'Ways to support';

  @override
  String get sponsorSupport => 'Sponsor support';

  @override
  String get sponsors => 'Sponsors';

  @override
  String get sponsorsThanks => 'Thanks to every supporter';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc =>
      'SSID is a callsign suffix for devices, e.g. -9 in BG7ABC-9';

  @override
  String get ssidDescShort =>
      'SSID is the numeric callsign suffix, such as -9 in BG7ABC-9';

  @override
  String get ssidOptional => 'SSID suffix (optional)';

  @override
  String get ssidSuffix => 'SSID suffix';

  @override
  String get start => 'Start';

  @override
  String get startGps => 'Start GPS';

  @override
  String get station => 'Station';

  @override
  String get stationActions => 'Station actions';

  @override
  String stationCount(Object count) {
    return '$count stations';
  }

  @override
  String get stationCount2 => 'Stations';

  @override
  String get stationDeleted => 'Station deleted';

  @override
  String get stationDetail => 'Station detail';

  @override
  String get stationFilterOn => 'Filtered by station panel';

  @override
  String get stationIdentity => 'Station identity';

  @override
  String get stationList => 'Stations';

  @override
  String get stationListDesc =>
      'Received stations and their tracks, stored on this device';

  @override
  String get stationListTitle => 'Stations';

  @override
  String stationNoData(String call) {
    return 'No data received from $call yet';
  }

  @override
  String get stationSettings => 'Station settings';

  @override
  String get stationSettings2 => 'Station settings';

  @override
  String get stationSettingsDetail => 'Callsign, SSID, symbol & comment';

  @override
  String get stationSettingsSubtitle => 'Callsign, symbol & beaconing';

  @override
  String get stationary => 'Stationary';

  @override
  String get stations => 'Stations';

  @override
  String get stationsCleared => 'Station list cleared';

  @override
  String get stationsShown => 'Stations';

  @override
  String get statistics => 'Statistics';

  @override
  String get statsAprslocusUsers => 'APRSlocus users';

  @override
  String get statsAvgSpeed => 'Avg speed';

  @override
  String get statsCap => 'Capacity';

  @override
  String get statsConn => 'Link';

  @override
  String get statsConnected => 'Connected';

  @override
  String get statsDeviceDist => 'Device classes';

  @override
  String get statsDisconnected => 'Offline';

  @override
  String get statsFarthest => 'Farthest';

  @override
  String statsGridCount(String n) {
    return '$n grids';
  }

  @override
  String get statsGridCountLabel => 'Grid squares';

  @override
  String get statsGridDist => 'Grid square breakdown';

  @override
  String get statsGridEmpty => 'No station positions yet';

  @override
  String get statsGridHint => 'Stations per Maidenhead field (4 chars), ranked';

  @override
  String get statsLastHeard => 'Last heard';

  @override
  String get statsMovingCount => 'Moving';

  @override
  String get statsMyGrid => 'My grid';

  @override
  String get statsNoData => 'No data';

  @override
  String get statsOnlineRate => 'Online rate';

  @override
  String get statsOther => 'Other metrics';

  @override
  String get statsOverview => 'System overview';

  @override
  String get statsPackets => 'Packets (recent)';

  @override
  String get statsPanel => 'Statistics';

  @override
  String statsPerMin(String n) {
    return '$n/min';
  }

  @override
  String get statsRate => 'Rate';

  @override
  String get statsStationsTotal => 'Stations';

  @override
  String get statsStatusDist => 'Status breakdown';

  @override
  String get statsTotalRx => 'Packets RX';

  @override
  String get statsTotalTx => 'Packets TX';

  @override
  String get statsTypeDist => 'Type breakdown';

  @override
  String get statusFilter => 'Status';

  @override
  String get statusType => 'Status';

  @override
  String get stepContent => 'Message';

  @override
  String get stepMembers => 'Members';

  @override
  String get stepName => 'Name';

  @override
  String get stepRecipients => 'Recipients';

  @override
  String get stoppedShort => 'Stopped';

  @override
  String get storageLimit => 'Data limits';

  @override
  String get storageLimitSubtitle => 'How much data to keep locally';

  @override
  String get supportProject => 'Your support helps the project go further';

  @override
  String get symAmbulance => 'Ambulance';

  @override
  String get symBalloon => 'Balloon';

  @override
  String get symBicycle => 'Bicycle';

  @override
  String get symBigAircraft => 'Large aircraft';

  @override
  String get symBus => 'Bus';

  @override
  String get symCamping => 'Camping';

  @override
  String get symCar => 'Car';

  @override
  String get symCatAirWater => 'Air / Water';

  @override
  String get symCatBuildings => 'Buildings / Facilities';

  @override
  String get symCatComms => 'Comms / Other';

  @override
  String get symCatEmergency => 'Emergency';

  @override
  String get symCatNature => 'Weather / Nature';

  @override
  String get symCatVehicles => 'Vehicles / Traffic';

  @override
  String get symCmdCenter => 'Command center';

  @override
  String get symDigi => 'Digital repeater';

  @override
  String get symDigiTower => 'Repeater tower';

  @override
  String get symDog => 'Dog';

  @override
  String get symDxCluster => 'DX cluster';

  @override
  String get symEmergCenter => 'Emergency center';

  @override
  String get symFileServer => 'File server';

  @override
  String get symFireAlarm => 'Fire alarm';

  @override
  String get symFireStation => 'Fire station';

  @override
  String get symFireTruck => 'Fire truck';

  @override
  String get symFmoStation => 'FMO station';

  @override
  String get symGlider => 'Glider';

  @override
  String get symGrid => 'Grid';

  @override
  String get symHandicap => 'Handicapped';

  @override
  String get symHfGateway => 'HF gateway';

  @override
  String get symHorse => 'Horseback';

  @override
  String get symHospital => 'Hospital';

  @override
  String get symHotel => 'Hotel';

  @override
  String get symHouse => 'House';

  @override
  String get symHurricane => 'Hurricane';

  @override
  String get symJeep => 'Jeep';

  @override
  String get symLaptop => 'Laptop';

  @override
  String get symMicE => 'Mic-E repeater';

  @override
  String get symMobileSat => 'Mobile satellite';

  @override
  String get symMotel => 'Motel';

  @override
  String get symMotorcycle => 'Motorcycle';

  @override
  String get symNode => 'Node';

  @override
  String get symPerson => 'Person';

  @override
  String get symPolice => 'Police';

  @override
  String get symPoliceCar => 'Police car';

  @override
  String get symPostOffice => 'Post office';

  @override
  String get symRedCross => 'Red Cross';

  @override
  String get symRv => 'RV';

  @override
  String get symSailboat => 'Sailboat';

  @override
  String get symSatAntenna => 'Satellite antenna';

  @override
  String get symSchool => 'School';

  @override
  String get symSemi => 'Semi-trailer';

  @override
  String get symShelter => 'Shelter';

  @override
  String get symShip => 'Ship';

  @override
  String get symSmallAircraft => 'Small aircraft';

  @override
  String get symSnowmobile => 'Snowmobile';

  @override
  String get symTelephone => 'Telephone';

  @override
  String get symTrain => 'Train';

  @override
  String get symTruck => 'Truck';

  @override
  String get symTruckStop => 'Truck stop';

  @override
  String get symVan => 'Van';

  @override
  String get symWater => 'Water station';

  @override
  String get symWeather => 'Weather';

  @override
  String get symWxStation => 'Weather station';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symYagi => 'Yagi';

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
  String get symbolLabel => 'Symbol';

  @override
  String sysBeacon(String t) {
    return 'Beacon $t';
  }

  @override
  String get sysEmpty =>
      'Open APRSlocus and connect to see your station status here';

  @override
  String get sysFixOk => 'Located';

  @override
  String get sysLinkAudio => 'Audio';

  @override
  String get sysLinkOff => 'Off';

  @override
  String get sysRecentLabel => 'Last heard';

  @override
  String sysRx(String n) {
    return 'Rx $n';
  }

  @override
  String sysStations(String n) {
    return 'Stations $n';
  }

  @override
  String get sysTitle => 'System status';

  @override
  String sysTx(String n) {
    return 'Tx $n';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call declined the invitation';
  }

  @override
  String get systemLog => 'System log';

  @override
  String systemMemberJoined(String call) {
    return '$call joined the group';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call left the group';
  }

  @override
  String get tapAnywhereClose => 'Tap anywhere to close';

  @override
  String get tapMapHint => 'Tap map for stations · pinch to zoom';

  @override
  String get tapToInvite => 'Tap to invite';

  @override
  String get tapToView => 'Double-tap beacon for more';

  @override
  String get telemetryTitle => 'Speed / Altitude';

  @override
  String get testMembers => 'Test members';

  @override
  String get testTxAction => 'Transmit test frame';

  @override
  String get testTxDesc =>
      'Sends a status packet to prove the link really reaches the air';

  @override
  String testTxFail(String err) {
    return 'Test frame failed: $err';
  }

  @override
  String get testTxHint =>
      'This **really transmits** (a status packet, no coordinates). Make sure you are operating within your licence and callsign';

  @override
  String get testTxNeedsConnect => 'Connect the link first';

  @override
  String get testTxSent => 'Test frame handed to the link';

  @override
  String get testTxTitle => 'Test transmit';

  @override
  String get thanks => 'Thanks';

  @override
  String get themeAccentFrom => 'Gradient start';

  @override
  String get themeAccentTo => 'Gradient end';

  @override
  String get themeActive => 'In use';

  @override
  String get themeAlignBottom => 'Bottom';

  @override
  String get themeAlignBottomLeft => 'Bottom left';

  @override
  String get themeAlignBottomRight => 'Bottom right';

  @override
  String get themeAlignCenter => 'Center';

  @override
  String get themeAlignLeft => 'Left';

  @override
  String get themeAlignRight => 'Right';

  @override
  String get themeAlignTop => 'Top';

  @override
  String get themeAlignTopLeft => 'Top left';

  @override
  String get themeAlignTopRight => 'Top right';

  @override
  String get themeAuthor => 'Author';

  @override
  String get themeAuthorHint => 'Your callsign or nickname';

  @override
  String get themeBg => 'Background image';

  @override
  String get themeBgAlign => 'Alignment';

  @override
  String get themeBgBlur => 'Blur';

  @override
  String get themeBgBlurDesc =>
      'Blurring removes photo detail so text on top stays legible';

  @override
  String get themeBgDesc =>
      'Use an image as the app backdrop; cards turn translucent automatically';

  @override
  String get themeBgDisabledHint =>
      'This theme has no background image; the backdrop is a solid colour';

  @override
  String get themeBgErrTooLarge =>
      'The background is larger than 8 MB — compress it first (icons are capped at 2 MB)';

  @override
  String get themeBgFit => 'Fill mode';

  @override
  String get themeBgFitContain => 'Contain';

  @override
  String get themeBgFitCover => 'Cover';

  @override
  String get themeBgFitStretch => 'Stretch';

  @override
  String get themeBgFitTile => 'Tile';

  @override
  String get themeBgLocalOnly =>
      'The image stays on this device: the theme file records only a reference, not the image, so anyone you share it with sees the theme without a background.';

  @override
  String get themeBgNone => 'Not set';

  @override
  String get themeBgOpacity => 'Opacity';

  @override
  String get themeBgOpacityDesc =>
      'Also sets the veil strength: higher shows more image and risks unreadable text';

  @override
  String get themeBgPick => 'Choose image';

  @override
  String get themeBgRemove => 'Remove background';

  @override
  String get themeBgReplace => 'Replace image';

  @override
  String get themeBgScale => 'Scale';

  @override
  String get themeBgScaleDesc =>
      '1.0 = original size; zoom in to show only part of the image';

  @override
  String get themeBuiltinHint =>
      'Presets cannot be edited — copy one to your themes first';

  @override
  String get themeColor => 'Theme color';

  @override
  String get themeColors => 'Colours';

  @override
  String get themeColorsDesc =>
      'Overwrite colours individually; untouched ones stay default';

  @override
  String get themeDelete => 'Delete theme';

  @override
  String themeDeleteConfirm(String name) {
    return 'Delete the theme “$name”? This cannot be undone.';
  }

  @override
  String get themeDensity => 'Density';

  @override
  String get themeDensityComfortable => 'Comfortable';

  @override
  String get themeDensityCompact => 'Compact';

  @override
  String get themeDensityHint =>
      'This changes card padding; if something looks unchanged, its spacing is fixed individually';

  @override
  String get themeDensityNormal => 'Normal';

  @override
  String get themeDescHint => 'One line about this skin';

  @override
  String get themeDescription => 'Description';

  @override
  String get themeDuplicate => 'Copy to my themes';

  @override
  String get themeEditText => 'Edit text';

  @override
  String get themeEntryDesc => 'Custom colours, icons and text';

  @override
  String get themeErrEmpty => 'The file contains no usable theme';

  @override
  String get themeErrNotJson => 'The file is not valid JSON';

  @override
  String get themeErrNotTheme => 'This is not an APRSlocus theme file';

  @override
  String get themeErrSchemaNewer =>
      'The theme comes from a newer APRSlocus — update the app first';

  @override
  String get themeExport => 'Export this theme';

  @override
  String get themeExportAll => 'Export all themes';

  @override
  String get themeExportClipboardTooBig =>
      'The images are too large for the clipboard — use \"Export all themes\" to save a file instead';

  @override
  String get themeExportNoImages =>
      'This theme references no images; the export contains only colours and text';

  @override
  String get themeExportWithImages => 'Include images in the export';

  @override
  String themeExportWithImagesHint(String size) {
    return 'The export will carry the images themselves (about $size), so the recipient sees the same background and icons. The file is then no longer hand-editable.';
  }

  @override
  String get themeFixedPrimary =>
      'The active theme pins the primary colour — change it on the Theme page';

  @override
  String get themeFollowsPrimary => 'Follows primary';

  @override
  String get themeFont => 'Font';

  @override
  String get themeFontDefault => 'System default';

  @override
  String get themeFontHint =>
      'Uses system-installed fonts only; if one is missing it falls back automatically (no tofu boxes)';

  @override
  String get themeFontMono => 'Monospace';

  @override
  String get themeFontSystem => 'System UI font';

  @override
  String get themeIconErrFailed => 'Could not import the icon';

  @override
  String get themeIconErrFormat =>
      'Unsupported image format (PNG/JPG/WebP/GIF/BMP/SVG)';

  @override
  String get themeIconErrTooLarge =>
      'The image is larger than 2 MB — please compress it';

  @override
  String get themeIconErrUnsupported =>
      'Importing images is not supported on this platform';

  @override
  String get themeIconImport => 'Import an image';

  @override
  String themeIconImportDone(String name) {
    return 'Icon imported: $name';
  }

  @override
  String get themeIconImportHint => 'PNG/JPG/WebP/GIF/BMP/SVG, up to 2 MB';

  @override
  String get themeIconWebHint =>
      'Importing images is not available on the web — use the built-in icon library';

  @override
  String get themeIcons => 'Icons';

  @override
  String get themeIconsDesc => 'Replace the tab bar and settings entries icons';

  @override
  String get themeImport => 'Import themes';

  @override
  String themeImportDone(int n) {
    return 'Imported $n themes';
  }

  @override
  String themeImportImagesSkipped(int n) {
    return '$n image(s) were not imported (too large or unsupported)';
  }

  @override
  String get themeImportPaste => 'Import from clipboard';

  @override
  String get themeIo => 'Import & export';

  @override
  String get themeIoDesc =>
      'A theme is JSON text — shareable and hand-editable';

  @override
  String get themeLayout => 'Density & font';

  @override
  String get themeLayoutDesc =>
      'Affects card and input padding only, not every spacing';

  @override
  String get themeNameHint => 'Theme name';

  @override
  String get themeNew => 'New theme';

  @override
  String get themeOverridden => 'Custom';

  @override
  String get themePickColor => 'Pick a colour';

  @override
  String get themePickIcon => 'Pick an icon';

  @override
  String get themePickIconSearch => 'Search icon names';

  @override
  String get themePresetAmber => 'Amber';

  @override
  String get themePresetContrast => 'High contrast';

  @override
  String get themePresetDefault => 'Default';

  @override
  String get themePresetForest => 'Forest';

  @override
  String get themePresetGraphite => 'Graphite';

  @override
  String get themePresetMidnight => 'Midnight';

  @override
  String get themePresetOcean => 'Ocean';

  @override
  String get themePresetSakura => 'Sakura';

  @override
  String get themePresetSunset => 'Sunset';

  @override
  String get themePresetTag => 'preset';

  @override
  String get themePresetTerminal => 'Terminal';

  @override
  String get themePresets => 'Presets & my themes';

  @override
  String get themePreviewSwatches => 'Preview swatches';

  @override
  String get themeRadius => 'Card corner radius';

  @override
  String get themeRadiusDesc =>
      'Applies to cards and inputs (small badges are unaffected)';

  @override
  String get themeRename => 'Rename';

  @override
  String get themeReset => 'Reset';

  @override
  String get themeResetAll => 'Reset this theme';

  @override
  String get themeSaved => 'Theme saved';

  @override
  String get themeSkinInfo => 'Skin info';

  @override
  String get themeSkinInfoDesc => 'Both travel with the skin when you share it';

  @override
  String get themeSubtitle =>
      'Make the colours, icons and common labels your own';

  @override
  String get themeSurface => 'Card surface';

  @override
  String get themeSurfaceAlpha => 'Opacity (lower is more see-through)';

  @override
  String get themeSurfaceAlphaDesc =>
      'Around 0.85 keeps coverage while showing the backdrop; below 0.6 text starts to smear';

  @override
  String get themeSurfaceDesc =>
      'With a background image, how translucent cards should be';

  @override
  String get themeSurfaceNoBg =>
      'No background image is set, so this has no visible effect yet';

  @override
  String get themeTabs => 'Accent colours';

  @override
  String get themeTabsDesc =>
      'The entry-card gradient, and a per-tab accent colour';

  @override
  String get themeTextHint => 'Leave empty to reset';

  @override
  String get themeTexts => 'Text';

  @override
  String get themeTextsDesc =>
      'Overwrite common labels (buttons and error messages are deliberately excluded so the UI stays operable)';

  @override
  String get themeTitle => 'Theme';

  @override
  String get themeTokenBackground => 'Page background';

  @override
  String get themeTokenBackgroundSoft => 'Secondary background';

  @override
  String get themeTokenDanger => 'Danger / offline';

  @override
  String get themeTokenDivider => 'Divider';

  @override
  String get themeTokenInfo => 'Info / accent';

  @override
  String get themeTokenPrimary => 'Primary';

  @override
  String get themeTokenSuccess => 'Success / online';

  @override
  String get themeTokenSurface => 'Card surface';

  @override
  String get themeTokenTextMuted => 'Muted text';

  @override
  String get themeTokenTextPrimary => 'Primary text';

  @override
  String get themeTokenTextSecondary => 'Secondary text';

  @override
  String get themeTokenWarning => 'Warning';

  @override
  String get themeUniformAccent => 'Unify entry-card colours';

  @override
  String get tierIdleShort => 'Idle/low';

  @override
  String get tierIdleTitle => 'Edit · Idle/low-speed tier';

  @override
  String get tierMinDist => 'Distance (m)';

  @override
  String get tierMinDistHint =>
      'Also beacon after moving this far since the last report; 0 = off (interval only)';

  @override
  String get tierMinTurn => 'Turn (degrees)';

  @override
  String get tierMinTurnHint =>
      'Beacon once after turning this far (10–180); 0 = off. Only while moving (heading is noise when parked)';

  @override
  String get tierSpeedTitle => 'Edit · Speed tier';

  @override
  String get time => 'Time';

  @override
  String get timeJustNow => 'just now';

  @override
  String get tncBindSubtitle => 'Bind and connect the TNC on your radio';

  @override
  String get tncBindTitle => 'Bluetooth TNC';

  @override
  String get tncBoundDevice => 'Bound device';

  @override
  String get tncConnectAction => 'Connect TNC';

  @override
  String get tncDeviceDesc =>
      'Bluetooth/serial binding, init string, KISS parameters and TX self-test';

  @override
  String get tncDeviceTitle => 'TNC device & parameters';

  @override
  String get tncErrBadFormat => 'malformed packet';

  @override
  String get tncErrFrameTooLong => 'frame exceeds the size limit';

  @override
  String get tncErrNoDevice => 'no TNC device bound';

  @override
  String get tncErrNotConnected => 'link not connected';

  @override
  String get tncErrOpenRead => 'cannot open device for reading';

  @override
  String get tncErrOpenWrite =>
      'cannot open device for writing — Windows COM ports are exclusive; check for another app holding it';

  @override
  String get tncErrTimeout => 'timed out';

  @override
  String get tncErrUnsupported => 'unsupported on this platform';

  @override
  String get tncGroupDisabled =>
      'Group broadcasts are unavailable in radio mode';

  @override
  String get tncInitDelay => 'Delay per line (ms)';

  @override
  String get tncInitDelayTip =>
      'Wait between lines. Modules need time to process commands; too short drops them';

  @override
  String get tncInitEmpty => 'No init string configured';

  @override
  String get tncInitSendAction => 'Send init string now';

  @override
  String tncInitSent(int n) {
    return 'Sent $n init line(s)';
  }

  @override
  String get tncInitSubtitle =>
      'Sent line by line after connecting (same as APRSdroid kiss.init)';

  @override
  String get tncInitTip =>
      'If the TNC receives but will not transmit, try here first: many Bluetooth/serial TNC modules boot into command mode and need KISS ON / RESTART before they will forward in KISS. One command per line (CRLF is appended automatically).';

  @override
  String get tncInitTitle => 'TNC init string';

  @override
  String get tncLog => 'Link log';

  @override
  String get tncLogEmpty => 'No log entries yet';

  @override
  String get tncMsgDesc =>
      'The radio channel is shared, so messaging is limited accordingly';

  @override
  String tncMsgLimitHint(String n) {
    return '$n characters per message (APRS spec)';
  }

  @override
  String get tncMsgTitle => 'Radio (TNC) mode';

  @override
  String get tncMsgTooLong => 'Exceeds the message length limit for radio mode';

  @override
  String get tncNeedConnected => 'Connect the TNC first';

  @override
  String get tncNeedPermission =>
      'Bluetooth permission is needed to scan for Bluetooth devices; ignore this if you only use USB serial — the system asks for that separately when you plug the cable in';

  @override
  String get tncNoPaired =>
      'No devices found — pair the TNC in the system Bluetooth settings, or plug in the USB serial cable (OTG)';

  @override
  String get tncNotBound => 'No bound device';

  @override
  String get tncOpenFailedHint =>
      'Could not open the device — Windows COM ports are exclusive; make sure no other app holds it';

  @override
  String get tncPushParams => 'Push KISS parameters on connect';

  @override
  String get tncPushParamsTip =>
      'Off by default (same as APRSdroid). When on, the values above are pushed to the TNC on connect, overriding its own configuration — inappropriate values can make it back off forever without transmitting, so enable only if you want centralised control.';

  @override
  String get tncRestart => 'Restart link';

  @override
  String get tncScanPaired => 'Scan devices (paired Bluetooth + USB serial)';

  @override
  String get tncSerialBaud => 'Serial baud rate (bd)';

  @override
  String get tncSerialBaudBluetooth =>
      'A Bluetooth device is bound: Bluetooth SPP has no baud rate, so this setting has no effect';

  @override
  String get tncSerialBaudHint =>
      'The new speed takes effect after reconnecting (sending the parameters reconnects once automatically)';

  @override
  String get tncSerialBaudTip =>
      'A USB serial cable and the radio data port must agree on the speed, otherwise not a single byte gets through. Common values: 9600 / 19200 / 38400 / 57600 / 115200. Bluetooth SPP has no baud rate, so this is ignored for Bluetooth devices.';

  @override
  String tncStats(String rx, String tx) {
    return '$rx frames received · $tx sent';
  }

  @override
  String get tncSupportedNo =>
      'TNC links are not supported on this platform yet';

  @override
  String get tncSwitchOff => 'Off';

  @override
  String get tncSwitchOn => 'On';

  @override
  String get tncTxTestAction => 'Write test frame';

  @override
  String tncTxTestFail(String err) {
    return 'Not written: $err';
  }

  @override
  String get tncTxTestHint =>
      'It sends a status frame (no coordinates), so it will not move your station on aprs.fi. If it reports \"written\" but nothing is transmitted, the problem is on the TNC side: try the init string (KISS ON / RESTART) first, then check TxDelay and channel occupancy.';

  @override
  String tncTxTestOk(String n) {
    return 'Written to the TNC ($n frames total). If the radio still does not transmit, the issue is on the TNC side: try the init string or check TxDelay.';
  }

  @override
  String get tncTxTestOkPrefix => 'Written';

  @override
  String get tncTxTestSubtitle =>
      'Writes one test frame to the TNC to tell link problems from TNC problems';

  @override
  String get tncTxTestTitle => 'TX self-test';

  @override
  String get tncUnbind => 'Unbind';

  @override
  String get totalStations => 'Total';

  @override
  String get track => 'Track';

  @override
  String get trackActive => 'Active';

  @override
  String get trackGroupEmpty =>
      'Members have no position data yet (not received or not beaconing).';

  @override
  String get trackGroupNameHint => 'Name, e.g. Weekend Ride';

  @override
  String get trackGroupsEmptyHint =>
      'No track groups yet. Tap “New track group” to create one.';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total members · $online online · $fixed fixed';
  }

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackModeFitAll => 'Keep-fit all';

  @override
  String trackModeFollow(Object call) {
    return 'Following $call';
  }

  @override
  String get trackModeMe => 'Following me';

  @override
  String trackPoints(int count) {
    return 'Track ($count points)';
  }

  @override
  String get trackWaitingPos => 'Waiting for position…';

  @override
  String get trackingBeaconing =>
      'Location is active and position beacons are being sent';

  @override
  String get translate => 'Translate';

  @override
  String get translateAuto => 'Auto-translate incoming messages';

  @override
  String translateAutoAllFailed(String e) {
    return 'All keyless endpoints failed ($e) · switch to a Google/Baidu key or your own instance in settings';
  }

  @override
  String get translateAutoTip =>
      'Applies to this conversation only; translates received messages only';

  @override
  String get translateBaiduAppId => 'Baidu App ID';

  @override
  String get translateBaiduKey => 'Baidu secret key';

  @override
  String get translateBaiduTip =>
      'Apply for general text translation on the Baidu Translate platform; the key stays on this device';

  @override
  String translateBubbleCount(int n) {
    return '$n translated';
  }

  @override
  String get translateContrast => 'Show original and translation together';

  @override
  String get translateContrastTip =>
      'When off only the translation shows (long-press still reveals the original)';

  @override
  String get translateCopyOriginal => 'Copy original';

  @override
  String get translateCopyResult => 'Copy translation';

  @override
  String get translateCustomBody => 'Body template';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return 'Placeholders: $text, $from, $to. Ignored when the method is GET';
  }

  @override
  String get translateCustomHeaders => 'Headers (JSON)';

  @override
  String get translateCustomMethod => 'HTTP method';

  @override
  String get translateCustomResultPath => 'Result JSON path';

  @override
  String get translateCustomResultPathTip =>
      'Dot-separated path with array indexes, e.g. data.translations.0.translatedText';

  @override
  String get translateCustomUrl => 'Endpoint URL';

  @override
  String translateFailed(String e) {
    return 'Translation failed: $e';
  }

  @override
  String translateFreeFailed(String e) {
    return 'The free endpoint is unavailable ($e) · switch to Google / Baidu / a custom endpoint in settings';
  }

  @override
  String get translateGoogleKey => 'Google API key';

  @override
  String get translateGoogleKeyTip =>
      'API key for Google Cloud Translation v2 — create one in the Google Cloud console';

  @override
  String get translateInput => 'Translate the input';

  @override
  String get translateLangAuto => 'Auto detect';

  @override
  String get translateLangScopeNote =>
      'Providers differ in language coverage (e.g. Baidu standard supports Indonesian “id”, but not every direction) — when unsupported, the app suggests Automatic or another provider';

  @override
  String get translateLangUnsupported =>
      'This provider cannot translate into that language · try “Automatic” or another provider';

  @override
  String get translateLearned => 'Auto-detected';

  @override
  String get translateLibreKey =>
      'Instance API key (needed for public instances; leave empty when self-hosted)';

  @override
  String get translateLibreUrl => 'Instance URL';

  @override
  String get translateMyLang => 'My language';

  @override
  String get translateMyLangHint =>
      'Messages from the other side are translated into this';

  @override
  String get translateNeedConfig => 'Configure the translation provider first';

  @override
  String get translateNotNeeded =>
      'Nothing to translate here (numbers / symbols / callsigns)';

  @override
  String get translateOutCancel => 'Cancel translation';

  @override
  String get translateOutNeedPeer =>
      'Their language is still unknown — set it in the conversation\'s translation settings';

  @override
  String translateOutPreview(String text) {
    return 'Will send: $text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return 'Translated into $lang · tap send to transmit this';
  }

  @override
  String get translateOutgoing =>
      'Translate into their language before sending';

  @override
  String get translateOutgoingTip =>
      'With this on, sending first translates the text into their language — make sure they can read it';

  @override
  String get translatePeerLang => 'The other party\'s language';

  @override
  String get translatePeerUnknown =>
      'The other party\'s language is still unknown — set it in translation settings, or it will be detected after a few of their messages';

  @override
  String get translatePeerUnknownHint =>
      'Detected automatically from their messages';

  @override
  String get translatePrivacyNote =>
      'Translation sends message text to the third-party provider you choose; assess privacy accordingly';

  @override
  String get translateProvider => 'Provider';

  @override
  String get translateProviderAuto => 'Automatic (recommended)';

  @override
  String get translateProviderAutoDesc =>
      'Tries several keyless endpoints in turn and keeps the first real translation';

  @override
  String get translateProviderBaidu => 'Baidu Translate';

  @override
  String get translateProviderCustom => 'Custom';

  @override
  String get translateProviderFree => 'Free (no key needed)';

  @override
  String get translateProviderFreeDesc =>
      'Works out of the box · uses a public endpoint that may be rate-limited or unstable';

  @override
  String get translateProviderGoogle => 'Google Translate';

  @override
  String get translateProviderGooglePublic =>
      'Google public endpoint (keyless)';

  @override
  String get translateProviderGooglePublicDesc =>
      'Good quality, but may be rate-limited (observed 429)';

  @override
  String get translateProviderLibre => 'LibreTranslate (self-hostable)';

  @override
  String get translateProviderLibreDesc =>
      'Open source and most reliable self-hosted; public instances now need a key and often lack Chinese';

  @override
  String get translateProviderMyMemory => 'MyMemory (keyless)';

  @override
  String get translateProviderMyMemoryDesc =>
      'Official free API, but it is a translation memory: returns the source text when it has no match';

  @override
  String get translateRetry => 'Translate again';

  @override
  String get translateSameLang =>
      'Translation is identical to the original · may need no translation, or the provider failed to translate';

  @override
  String translateSentAs(String text) {
    return 'Sent in their language: $text';
  }

  @override
  String get translateSettings => 'Translation settings';

  @override
  String get translateSettingsSubtitle =>
      'Provider, languages and auto-translate';

  @override
  String get translateShowOriginal => 'Show original';

  @override
  String get translateShowTranslation => 'Show translation';

  @override
  String get translateSideIncoming => 'received';

  @override
  String get translateSideOutgoing => 'sent';

  @override
  String get translateSourceLang => 'Source language';

  @override
  String get translateTargetLang => 'Translate into';

  @override
  String get translateTest => 'Test translation';

  @override
  String translateTestOk(String text) {
    return 'Provider works: $text';
  }

  @override
  String get translateText => 'Translate text';

  @override
  String get translateToMeTag => 'for me';

  @override
  String get translateToPeerTag => 'what they read';

  @override
  String translateTooLongAfter(int n) {
    return 'Translation exceeds the length limit ($n chars) — not sent';
  }

  @override
  String get translateTranslating => 'Translating…';

  @override
  String get translateUntranslated =>
      'The endpoint did not actually translate (it returned the source text) — tried the next one';

  @override
  String get translateUsedProvider => 'Actually used';

  @override
  String get txButton => 'Transmit';

  @override
  String get txNothingFilled => 'All fields are empty - nothing to send';

  @override
  String get txPartPosition => 'position packet';

  @override
  String get txPartStatus => 'status packet';

  @override
  String txSent(String parts) {
    return 'Transmitted: $parts';
  }

  @override
  String get typeFilter => 'Type';

  @override
  String get typeGroup => 'Type';

  @override
  String get uiLayout => 'UI layout';

  @override
  String get uiLayoutClassic => 'Classic layout (1.0)';

  @override
  String get uiLayoutClassicDesc =>
      'Side rail on wide screens, bottom navigation on narrow ones — exactly as before';

  @override
  String get uiLayoutDesc =>
      '2.0 uses the map as the base of the whole UI, with the other pages in a draggable card at the bottom';

  @override
  String get uiLayoutHint =>
      'Takes effect immediately; both layouts keep their own settings. Map controls move up automatically as the card collapses';

  @override
  String get uiLayoutSheet => 'Map-first (2.0)';

  @override
  String get uiLayoutSheetDesc =>
      'The map stays full-screen; stations / messages / packets / settings live in a draggable card below — swipe up or tap the handle to expand';

  @override
  String get uiMaterial => 'UI material';

  @override
  String get uiMaterialBgHint =>
      'This theme uses a background image, so the material adds no backdrop of its own and only frosts the bars and overlays.';

  @override
  String get uiMaterialDesc =>
      'Make cards, bars and dialogs translucent, with a real blur behind them';

  @override
  String get uiMaterialGlass => 'Frosted glass';

  @override
  String get uiMaterialGlassDesc =>
      'More transparent with a stronger blur — like Windows 11 Acrylic';

  @override
  String get uiMaterialGlassFull => 'Full frosted glass';

  @override
  String get uiMaterialGlassFullDesc =>
      'The most transparent and the blurriest, **including the small widgets** (map tool buttons, legend, hint pills) — the heaviest look, and the heaviest on the GPU';

  @override
  String get uiMaterialHint =>
      'The material only affects the app\'s own surfaces (cards, bars, dialogs, map overlays) — it is not window transparency. Blur costs GPU time, so on older devices it may feel less smooth than Off.';

  @override
  String get uiMaterialMica => 'Mica';

  @override
  String get uiMaterialMicaDesc =>
      'More solid with a lighter blur and a tint of your accent colour — like Windows 11 Mica';

  @override
  String get uiMaterialOff => 'Off (solid)';

  @override
  String get uiMaterialOffDesc => 'Solid surfaces, exactly as before';

  @override
  String get uiMaterialPreview => 'Preview';

  @override
  String get uiScale => 'UI scale';

  @override
  String get unblock => 'Unblock';

  @override
  String get underConstruction => 'Under construction — not open yet';

  @override
  String get underConstructionHint =>
      'This feature is still being built. Please stay tuned.';

  @override
  String get unfavorite => 'Remove from favorites';

  @override
  String get unit => 'Unit';

  @override
  String get unitSeconds => 's';

  @override
  String get unknown => 'Unknown';

  @override
  String get unlocated => 'No fix';

  @override
  String get unverified => 'Unverified';

  @override
  String get updateCat => 'Update';

  @override
  String get updateCatDesc => 'Check for updates';

  @override
  String get updateChannel => 'Update channel';

  @override
  String get updateContents => 'What’s new';

  @override
  String get updateFailed => 'Update check failed';

  @override
  String get usageNotice =>
      'For amateur-radio learning and communication only\nFollow your local radio regulations';

  @override
  String get useDeviceLocation => 'Use device location';

  @override
  String get useMyLocation => 'Use my position as filter center';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String vectorMapLoadFailed(String error) {
    return 'Vector map failed to load\n$error';
  }

  @override
  String get version => 'Version';

  @override
  String versionChangelog(String version) {
    return 'v$version changelog';
  }

  @override
  String versionCount(int count) {
    return '$count versions';
  }

  @override
  String get viewChangelog => 'View changelog';

  @override
  String get viewSponsorDetails => 'View author and sponsor details →';

  @override
  String get waitingForLocation => 'Waiting for location';

  @override
  String get warning => 'Warning';

  @override
  String get weather => 'Weather';

  @override
  String get weatherAQIPrimary => 'Primary';

  @override
  String get weatherAir => 'AQI';

  @override
  String get weatherCloud => 'Cloud';

  @override
  String get weatherConnFail => 'Weather service connection failed';

  @override
  String get weatherCurLoc => 'Current location';

  @override
  String get weatherDaily15 => 'View 15-day weather';

  @override
  String get weatherDaily15Title => '15-Day Weather Trend';

  @override
  String get weatherData => 'Weather data';

  @override
  String get weatherDataFail => 'Failed to fetch weather data';

  @override
  String weatherDataValue(String data) {
    return 'Weather · $data';
  }

  @override
  String get weatherDayAfter => 'Day after';

  @override
  String get weatherDetails => 'Details';

  @override
  String get weatherDew => 'Dew pt';

  @override
  String weatherFeels(String v) {
    return 'Feels $v°';
  }

  @override
  String get weatherForecast3 => '3-Day Forecast';

  @override
  String get weatherHumidity => 'Humidity';

  @override
  String get weatherNoLoc =>
      'No location yet — enable location in My Station to view weather';

  @override
  String weatherObserved(String t) {
    return 'Observed $t';
  }

  @override
  String get weatherPanelSub => 'QWeather · Current Location';

  @override
  String get weatherPanelTitle => 'Weather · Ham Tips';

  @override
  String get weatherPowered => 'Powered by QWeather · APRSlocus';

  @override
  String get weatherPrecip => 'Precip.';

  @override
  String get weatherPressure => 'Pressure';

  @override
  String get weatherRefresh => 'Refresh';

  @override
  String get weatherSimDesc =>
      'After choosing, tap the weather pill in the top bar to preview; \"Follow live\" restores real weather';

  @override
  String get weatherSimFollowLive => 'Follow live';

  @override
  String get weatherSimTitle =>
      'Weather simulation (preview background/effects/advice)';

  @override
  String get weatherSunrise => 'Sunrise';

  @override
  String get weatherSunset => 'Sunset';

  @override
  String get weatherToday => 'Today';

  @override
  String get weatherTomorrow => 'Tomorrow';

  @override
  String get weatherUV => 'UV';

  @override
  String get weatherUnavail => 'Weather service unavailable';

  @override
  String get weatherVis => 'Visibility';

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
  String get weatherWidget => 'Weather widget';

  @override
  String get weatherWindDir => 'Wind dir';

  @override
  String get weatherWindScale => 'Wind';

  @override
  String get weatherWindSpeed => 'Wind spd';

  @override
  String get webLocationUnsupported =>
      'Automatic location is unavailable on the web; enter coordinates manually';

  @override
  String get website => 'Website';

  @override
  String get websocketOptional => 'WebSocket URL (optional)';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String windowsInstallHelp(String path) {
    return 'Installer saved to:\n$path\n\nTap “Run now” to launch it, or open the containing folder.';
  }

  @override
  String get wizard => 'Setup wizard';

  @override
  String get wsUrlOptional => 'WebSocket URL (optional)';

  @override
  String get wxClear => 'Clear';

  @override
  String get wxCloudy => 'Cloudy';

  @override
  String get wxFog => 'Fog';

  @override
  String get wxHeavyRain => 'Heavy rain';

  @override
  String get wxLightRain => 'Light rain';

  @override
  String get wxModerateRain => 'Moderate rain';

  @override
  String get wxOvercast => 'Overcast';

  @override
  String get wxSnow => 'Snow';

  @override
  String get wxStormRain => 'Torrential rain';

  @override
  String get wxThunder => 'Thundershower';

  @override
  String zoomLevel(Object z) {
    return 'Zoom $z';
  }

  @override
  String get advancedMenu => 'Advanced';


  @override
  String get beaconAltTip => 'When set, this manually entered altitude is used (more reliable: on phones without a barometer, indoors, or with network-only positioning the GPS altitude is often unusable). Left empty, the altitude from the fix is used. It is encoded as six zero-padded feet in the /A= extension. This is station altitude - a different quantity from the PHG antenna height below (above average local terrain).';

  @override
  String get beaconAltWillSend => 'Will send:';






  @override
  String get batteryNoFix => 'No fix yet - cannot beacon a position';

  @override
  String get aprsStatusHint => 'This sends a standalone status packet (starts with `>`, carries no coordinates, and does not move you on aprs.fi) - a different APRS packet type from the comment above. Left empty, the built-in APRSlocus online frame is sent instead.';

}
