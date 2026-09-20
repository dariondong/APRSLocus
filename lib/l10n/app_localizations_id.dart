// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Batal';

  @override
  String get save => 'Simpan';

  @override
  String get delete => 'Hapus';

  @override
  String get confirm => 'Konfirmasi';

  @override
  String get back => 'Kembali';

  @override
  String get next => 'Berikutnya';

  @override
  String get finish => 'Selesai & Sambungkan';

  @override
  String get previous => 'Sebelumnya';

  @override
  String get search => 'Cari';

  @override
  String get settings => 'Pengaturan';

  @override
  String get greetMorning => 'Selamat pagi, ';

  @override
  String get greetNoon => 'Selamat siang, ';

  @override
  String get greetAfternoon => 'Selamat sore, ';

  @override
  String get greetEvening => 'Selamat malam, ';

  @override
  String get greetNight => 'Selamat malam, ';

  @override
  String get about => 'Tentang';

  @override
  String get logout => 'Keluar';

  @override
  String get retry => 'Coba lagi';

  @override
  String get all => 'Semua';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get moving => 'Bergerak';

  @override
  String get emergency => 'Darurat';

  @override
  String get fixed => 'Tetap';

  @override
  String get infrastructure => 'Digipeater';

  @override
  String get weather => 'Cuaca';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => 'Mobile';

  @override
  String get favorite => 'Favorit';

  @override
  String get grid => 'Grid';

  @override
  String get callsign => 'Tanda panggil';

  @override
  String get speed => 'Kecepatan';

  @override
  String get altitude => 'Ketinggian';

  @override
  String get course => 'Arah';

  @override
  String get distance => 'Jarak';

  @override
  String get bearing => 'Azimut';

  @override
  String get lastSeen => 'Terakhir terdengar';

  @override
  String get latitude => 'Lintang';

  @override
  String get longitude => 'Bujur';

  @override
  String get station => 'Stasiun';

  @override
  String get stations => 'Stasiun';

  @override
  String get messages => 'Pesan';

  @override
  String get packets => 'Paket';

  @override
  String get map => 'Peta';

  @override
  String get home => 'Beranda';

  @override
  String get connection => 'Koneksi';

  @override
  String get connected => 'Terhubung';

  @override
  String get disconnected => 'Terputus';

  @override
  String get connecting => 'Menghubungkan';

  @override
  String get reconnect => 'Sambung ulang';

  @override
  String get server => 'Server';

  @override
  String get port => 'Port';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => 'Beacon posisi';

  @override
  String get beaconInterval => 'Interval kirim (dtk)';

  @override
  String get nextBeacon => 'Beacon berikutnya';

  @override
  String get beaconsSent => 'Beacon terkirim';

  @override
  String get symCatVehicles => 'Kendaraan / Lalu lintas';

  @override
  String get symCatBuildings => 'Bangunan / Fasilitas';

  @override
  String get symCatNature => 'Cuaca / Alam';

  @override
  String get symCatAirWater => 'Udara / Perairan';

  @override
  String get symCatComms => 'Komunikasi / Lainnya';

  @override
  String get homeBadgeLabel => 'Lencana di beranda';

  @override
  String get homeBadgePickTitle => 'Pilih lencana untuk beranda';

  @override
  String get homeBadgePickDesc =>
      'Pilih satu lencana yang sudah diperoleh untuk ditampilkan di beranda';

  @override
  String get simLocationHint => 'Gunakan lokasi simulasi (tanpa GPS)';

  @override
  String get speedTierRules => 'Aturan tingkat kecepatan';

  @override
  String get restoreDefaults => 'Kembalikan bawaan';

  @override
  String get speedTierDesc =>
      'Semakin cepat bergerak, semakin sering lapor; tiap tingkat dapat punya interval dan ikon sendiri (kosong = simbol saya).';

  @override
  String get speedTierShortIntervalWarn =>
      'Interval di bawah 60 dtk menambah beban server secara signifikan; disarankan ≥60 dtk.';

  @override
  String get addSpeedTier => 'Tambah tingkat kecepatan';

  @override
  String get maxSpeedTiers => 'Maksimal 5 tingkat kecepatan';

  @override
  String get iconDefaultMySymbol => 'Ikon · Bawaan (simbol saya)';

  @override
  String iconNamed(String name) {
    return 'Ikon · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return 'Setiap $sec dtk';
  }

  @override
  String get tierIdleTitle => 'Edit · Tingkat diam/lambat';

  @override
  String get tierSpeedTitle => 'Edit · Tingkat kecepatan';

  @override
  String get minSpeedKmh => 'Kecepatan minimum (km/j)';

  @override
  String get intervalSeconds => 'Interval kirim (dtk)';

  @override
  String get idleTierDesc =>
      'Kecepatan di bawah tingkat bergerak pertama dikirim memakai tingkat ini';

  @override
  String get intervalLabel => 'Interval';

  @override
  String get unitSeconds => 'dtk';

  @override
  String get pickBeaconIconDesc =>
      'Pilih ikon beacon · \"Bawaan\" = pakai simbol saya';

  @override
  String get defaultLabel => 'Bawaan';

  @override
  String get deleteThisTier => 'Hapus tingkat ini';

  @override
  String get idleTierNotDeletable => 'Tingkat diam tidak dapat dihapus';

  @override
  String get errMinSpeedInt => 'Kecepatan minimum harus bilangan bulat ≥ 1';

  @override
  String get errIntervalInt =>
      'Interval kirim harus bilangan bulat minimal 5 dtk';

  @override
  String get errTierDuplicate =>
      'Tingkat kecepatan itu sudah ada; nilai ambang harus berbeda';

  @override
  String get wsUrlOptional => 'URL WebSocket (opsional)';

  @override
  String get countryUnrestricted =>
      'Tanpa negara/region · tanpa batas (terima semua stasiun)';

  @override
  String get weatherWidget => 'Widget cuaca';

  @override
  String get groupChatLabel => 'Obrolan grup';

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
    return 'Hapus semua $n riwayat obrolan? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get weatherSimFollowLive => 'Ikuti waktu nyata';

  @override
  String get wxClear => 'Cerah';

  @override
  String get wxCloudy => 'Berawan';

  @override
  String get wxOvercast => 'Mendung';

  @override
  String get wxLightRain => 'Hujan ringan';

  @override
  String get wxModerateRain => 'Hujan sedang';

  @override
  String get wxHeavyRain => 'Hujan lebat';

  @override
  String get wxStormRain => 'Hujan sangat lebat';

  @override
  String get wxThunder => 'Hujan petir';

  @override
  String get wxSnow => 'Salju';

  @override
  String get wxFog => 'Kabut';

  @override
  String get weatherSimTitle => 'Simulasi cuaca (pratinjau latar/efek/saran)';

  @override
  String get weatherSimDesc =>
      'Setelah memilih, ketuk kapsul cuaca di bilah atas untuk pratinjau; \"Ikuti waktu nyata\" mengembalikan cuaca asli';

  @override
  String get restartWizardConfirm =>
      'Panduan awal akan dibuka lagi sehingga Anda dapat mengatur ulang tanda panggil, area terima, dan lainnya.\nPengaturan Anda saat ini tetap tersimpan; lanjutkan memakai aplikasi setelah panduan selesai.';

  @override
  String get restartWizardButton => 'Jalankan lagi';

  @override
  String get pasteAprsPacketHint =>
      'Tempel paket APRS mentah, mis.:\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Stasiun uji';

  @override
  String beaconsSentCount(String n) {
    return '$n kali';
  }

  @override
  String get myBadgesAndAchievements => 'Lencana dan pencapaian saya';

  @override
  String get quitApp => 'Keluar dari aplikasi';

  @override
  String get quitAppDesc =>
      'Keluar akan menghentikan pelaporan lokasi dan penerimaan di latar belakang, lalu mengakhiri proses.';

  @override
  String get symCar => 'Mobil';

  @override
  String get openInBrowser => 'Buka di browser';

  @override
  String get badgeWall => 'Dinding lencana';

  @override
  String get achievementWall => 'Dinding pencapaian';

  @override
  String get mapTypeCartoPositron => 'Carto Positron (vektor terang)';

  @override
  String get mapTypeCarto => 'Carto Terang';

  @override
  String get mapTypeCartoDark => 'Carto Gelap';

  @override
  String get mapTypeCartoVoyager => 'Carto Voyager';

  @override
  String get mapTypeOsm => 'OSM Standar';

  @override
  String get mapTypeOsmHot => 'OSM Humanitarian';

  @override
  String get mapTypeOpenTopo => 'OpenTopo Terrain';

  @override
  String get mapTypeEsriStreet => 'Esri Streets';

  @override
  String get mapTypeEsriSat => 'Esri Citra';

  @override
  String get simulatedKeepAlive => 'Lokasi simulasi · tetap aktif';

  @override
  String get symCatEmergency => 'Tanggap darurat';

  @override
  String get symSmallAircraft => 'Pesawat kecil';

  @override
  String myPositionSet(String grid) {
    return 'Lokasi saya tersimpan, grid $grid';
  }

  @override
  String get tierIdleShort => 'Diam/lambat';

  @override
  String get symHouse => 'Rumah';

  @override
  String get symPerson => 'Orang';

  @override
  String get symTruck => 'Truk';

  @override
  String get symBicycle => 'Sepeda';

  @override
  String get symRv => 'RV';

  @override
  String get symWxStation => 'Stasiun cuaca';

  @override
  String get symPolice => 'Polisi';

  @override
  String get symMotorcycle => 'Sepeda motor';

  @override
  String get symSemi => 'Truk gandeng';

  @override
  String get symVan => 'Van';

  @override
  String get symJeep => 'Jeep';

  @override
  String get symBus => 'Bus';

  @override
  String get symTruckStop => 'Tempat istirahat truk';

  @override
  String get symTrain => 'Kereta';

  @override
  String get symFireTruck => 'Mobil pemadam';

  @override
  String get symPoliceCar => 'Mobil polisi';

  @override
  String get symSnowmobile => 'Mobil salju';

  @override
  String get symYagi => 'Antena Yagi';

  @override
  String get symHospital => 'Rumah sakit';

  @override
  String get symAmbulance => 'Ambulans';

  @override
  String get symFireStation => 'Pos pemadam';

  @override
  String get symSchool => 'Sekolah';

  @override
  String get symMotel => 'Motel';

  @override
  String get symHotel => 'Hotel';

  @override
  String get symLaptop => 'Laptop';

  @override
  String get symPostOffice => 'Kantor pos';

  @override
  String get symWeather => 'Cuaca';

  @override
  String get symWater => 'Stasiun air';

  @override
  String get symHurricane => 'Badai';

  @override
  String get symHorse => 'Berkuda';

  @override
  String get symDog => 'Anjing';

  @override
  String get symCamping => 'Berkemah';

  @override
  String get symShelter => 'Tempat berlindung';

  @override
  String get symRedCross => 'Palang merah';

  @override
  String get symFireAlarm => 'Alarm kebakaran';

  @override
  String get symEmergCenter => 'Pusat darurat';

  @override
  String get symCmdCenter => 'Pusat komando';

  @override
  String get symHandicap => 'Difabel';

  @override
  String get symBigAircraft => 'Pesawat besar';

  @override
  String get symGlider => 'Pesawat layang';

  @override
  String get symBalloon => 'Balon';

  @override
  String get symShip => 'Kapal';

  @override
  String get symSailboat => 'Kapal layar';

  @override
  String get symMobileSat => 'Satelit bergerak';

  @override
  String get symSatAntenna => 'Antena satelit';

  @override
  String get symDigi => 'Digipeater';

  @override
  String get symDigiTower => 'Menara repeater';

  @override
  String get symMicE => 'Repeater Mic-E';

  @override
  String get symNode => 'Node';

  @override
  String get symDxCluster => 'Kluster DX';

  @override
  String get symHfGateway => 'Gateway HF';

  @override
  String get symFileServer => 'Server berkas';

  @override
  String get symTelephone => 'Telepon';

  @override
  String get symGrid => 'Grid';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'Stasiun FMO';

  @override
  String get filter => 'Filter jangkauan';

  @override
  String get filterRadius => 'Radius filter (km)';

  @override
  String get maxStations => 'Maks. stasiun';

  @override
  String get receiveFilter => 'Filter tanda panggil';

  @override
  String get receiveCountries => 'Negara/Wilayah';

  @override
  String get receiveOthers => 'Stasiun lain';

  @override
  String get darkMode => 'Mode gelap';

  @override
  String get themeColor => 'Warna tema';

  @override
  String get language => 'Bahasa';

  @override
  String get languageSystem => 'Ikuti sistem';

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
  String get languageEs => 'Spanyol';

  @override
  String get displaySettings => 'Pengaturan tampilan';

  @override
  String get uiScale => 'Skala UI';

  @override
  String get reloadUi => 'Muat ulang UI';

  @override
  String get reloadDone => 'Selesai dimuat ulang';

  @override
  String get mapType => 'Jenis peta';

  @override
  String get unit => 'Satuan';

  @override
  String get coordDatum => 'Datum koordinat';

  @override
  String get stationSettings => 'Pengaturan stasiun';

  @override
  String get connectionSettings => 'Pengaturan koneksi';

  @override
  String get chatSettings => 'Pengaturan obrolan';

  @override
  String get dataSettings => 'Pengaturan data';

  @override
  String get advancedSettings => 'Pengaturan lanjutan';

  @override
  String get sponsors => 'Sponsor & ucapan terima kasih';

  @override
  String get sponsorsThanks => 'Terima kasih kepada setiap pendukung';

  @override
  String get send => 'Kirim';

  @override
  String get receive => 'Terima';

  @override
  String get clear => 'Hapus';

  @override
  String get copy => 'Salin';

  @override
  String get copied => 'Tersalin';

  @override
  String get version => 'Versi';

  @override
  String get location => 'Lokasi';

  @override
  String get gpsStatus => 'Status GPS';

  @override
  String get myLocation => 'Lokasi saya';

  @override
  String get track => 'Jejak';

  @override
  String get forwardingPath => 'Jalur';

  @override
  String get relatedStations => 'Stasiun terkait';

  @override
  String get openInMap => 'Lihat di peta';

  @override
  String get navigate => 'Navigasi';

  @override
  String get messageSent => 'Pesan terkirim';

  @override
  String get enterMessage => 'Ketik pesan';

  @override
  String get noData => 'Tidak ada data';

  @override
  String get searchHint => 'Cari tanda panggil / jenis / grid / komentar…';

  @override
  String get notFound => 'Stasiun tidak ditemukan';

  @override
  String get totalStations => 'Total';

  @override
  String get sortBy => 'Urutkan';

  @override
  String get sortCall => 'Tanda panggil';

  @override
  String get sortRecent => 'Terbaru';

  @override
  String get sortDistance => 'Jarak';

  @override
  String get sortStatus => 'Status';

  @override
  String get typeFilter => 'Filter jenis';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => 'Hapus ini?';

  @override
  String get confirmRestartOobe =>
      'Panduan awal akan dibuka lagi; Anda dapat mengatur ulang tanda panggil, area terima, dan lainnya.\nPengaturan saat ini tetap tersimpan; lanjutkan memakai aplikasi setelah panduan selesai.';

  @override
  String get restartWizard => 'Jalankan panduan lagi';

  @override
  String get restartWizardTitle => 'Jalankan panduan lagi?';

  @override
  String get oobeFilterTitle => 'Pilih area terima';

  @override
  String get oobeFilterDesc =>
      'Pilih negara/wilayah yang ingin diterima. Jika tidak ada yang dipilih, semua stasiun akan diterima tanpa batasan.';

  @override
  String get oobeWelcomeTitle => 'Selamat datang di APRSlocus';

  @override
  String get oobeWelcomeRealMap => 'Peta waktu nyata';

  @override
  String get oobeWelcomeGps => 'Pelaporan posisi GPS';

  @override
  String get oobeWelcomeMsg => 'Pesan APRS';

  @override
  String get oobeWelcomeIs => 'Umpan APRS-IS';

  @override
  String get oobeCallTitle => 'Tanda panggil Anda';

  @override
  String get oobeSymbolTitle => 'Pilih simbol stasiun';

  @override
  String get oobeServerTitle => 'Sambungkan ke server APRS-IS';

  @override
  String get weatherData => 'Data cuaca';

  @override
  String get fmoInfo => 'Info stasiun FMO';

  @override
  String get aprslocusInfo => 'Info APRSlocus';

  @override
  String get locationInfo => 'Lokasi';

  @override
  String get recentPackets => 'Paket terbaru';

  @override
  String get quickActions => 'Aksi cepat';

  @override
  String get copyCoords => 'Salin koordinat';

  @override
  String get copyGrid => 'Salin grid';

  @override
  String get sender => 'Pengirim';

  @override
  String get time => 'Waktu';

  @override
  String get message => 'Pesan';

  @override
  String get groupChat => 'Obrolan grup';

  @override
  String get newGroup => 'Grup baru';

  @override
  String get sendTo => 'Kirim ke';

  @override
  String get filterRule => 'Aturan filter';

  @override
  String get saveAndApply => 'Simpan & terapkan filter';

  @override
  String get useMyLocation => 'Pakai posisi saya sebagai pusat filter';

  @override
  String get noFixYet => 'Belum ada posisi; lokasi saat ini tidak tersedia';

  @override
  String get invalidCoords => 'Masukkan lintang, bujur, dan radius yang valid';

  @override
  String get filterSaved => 'Filter tersimpan dan diterapkan';

  @override
  String get stationsShown => 'Stasiun';

  @override
  String get settingsDesc => 'Atur stasiun, lokasi & koneksi';

  @override
  String get radioCat => 'Stasiun';

  @override
  String get radioCatDesc => 'Tanda panggil · SSID · Simbol';

  @override
  String get beaconCat => 'Pelaporan beacon';

  @override
  String get beaconCatDesc => 'GPS · Beacon · Posisi manual';

  @override
  String get connectionCat => 'Koneksi';

  @override
  String get connectionCatDesc => 'Server · Jangkauan filter';

  @override
  String get displayCat => 'Tampilan';

  @override
  String get displayCatDesc => 'Koordinat · Tema';

  @override
  String get chatCat => 'Obrolan';

  @override
  String get chatCatDesc => 'Riwayat · Kontak';

  @override
  String get dataCat => 'Data';

  @override
  String get dataCatDesc => 'Hapus data lokal';

  @override
  String get advancedCat => 'Lanjutan';

  @override
  String get advancedCatDesc => 'Lab · Pengembang';

  @override
  String get updateCat => 'Pembaruan';

  @override
  String get updateCatDesc => 'Periksa versi baru';

  @override
  String get checkUpdate => 'Periksa pembaruan';

  @override
  String get myStationSettings => 'Stasiun saya';

  @override
  String get myStationSettingsDesc => 'Tanda panggil · SSID · Simbol · Beacon';

  @override
  String get oobeWelcomeDesc => 'Mulai mengatur stasiun APRS Anda';

  @override
  String get oobeCallDesc => 'Masukkan tanda panggil Anda';

  @override
  String get oobeSymbolDesc =>
      'Simbol menunjukkan jenis stasiun Anda dan dikirim bersama beacon posisi';

  @override
  String get oobeServerDesc =>
      'Setelah tersambung, Anda menerima data stasiun APRS sedunia. Pengaturan bawaan bisa langsung dipakai';

  @override
  String get wizard => 'Panduan penyiapan';

  @override
  String get setStep => 'Langkah';

  @override
  String get chooseSymbol => 'Pilih simbol stasiun';

  @override
  String get settingsSubtitle => 'Koordinat peta & preferensi tampilan';

  @override
  String get stationSettingsSubtitle => 'Tanda panggil, simbol & beacon';

  @override
  String get connectionSettingsSubtitle => 'Server APRS-IS & jangkauan terima';

  @override
  String get chatSettingsSubtitle => 'Riwayat pesan & kontak';

  @override
  String get dataSettingsSubtitle => 'Manajemen data lokal';

  @override
  String get advancedSettingsSubtitle => 'Lab & alat pengembang';

  @override
  String get stationListTitle => 'Daftar stasiun';

  @override
  String get filters => 'Filter';

  @override
  String get clearAll => 'Hapus semua';

  @override
  String get statusFilter => 'Status';

  @override
  String get typeGroup => 'Jenis';

  @override
  String get appFilter => 'Perangkat lunak';

  @override
  String get mapMenu => 'Menu peta';

  @override
  String get mapTypeTitle => 'Jenis peta';

  @override
  String get selectMapType => 'Pilih jenis peta';

  @override
  String get showTrails => 'Tampilkan jejak';

  @override
  String get showStations => 'Tampilkan stasiun';

  @override
  String get aboutTitle => 'Tentang';

  @override
  String get aboutSubtitle => 'Pelacakan & peta APRS';

  @override
  String get author => 'Penulis';

  @override
  String get codeContributions => 'Kontribusi kode';

  @override
  String get codeContributionI18n => 'Internasionalisasi / UI Inggris';

  @override
  String get codeContributionZhTw => 'UI Tionghoa Tradisional';

  @override
  String get codeContributionTranslation => 'Terjemahan';

  @override
  String get dataSourceTxHint =>
      'Beberapa tautan dapat diaktifkan sekaligus untuk menerima, tetapi **hanya satu yang memancar** (titik di kanan). Mengirim tanda panggil sama lewat dua tautan akan menduplikasi paket.';

  @override
  String get dataSourceTxBadge => 'TX';

  @override
  String get dataSourceIgateHint =>
      'Untuk menjadi gateway (meneruskan paket RF ke internet), aktifkan APRS-IS dan TNC/audio, lalu nyalakan \"Gateway\" di bawah.';

  @override
  String get igateTitle => 'Gateway (iGate)';

  @override
  String get igateSubtitle => 'Teruskan paket RF ke APRS-IS';

  @override
  String get igateEnable => 'Aktifkan gateway';

  @override
  String get igateHint =>
      'Paket yang diterima di RF diteruskan ke APRS-IS, ditandai qAr/qAR dan tanda panggil Anda. Perlu APRS-IS dan sumber RF (TNC/audio) aktif.';

  @override
  String get igateNeedRf =>
      'Belum ada sumber RF: centang TNC atau audio di \"Sumber data\" di atas.';

  @override
  String get igateNeedIs => 'APRS-IS belum aktif: centang di atas.';

  @override
  String get igateTwoWay => 'Gateway dua arah (teruskan pesan ke RF)';

  @override
  String get igateTwoWayHint =>
      'Bila aktif, ini **memancar di RF**: hanya pesan point-to-point untuk stasiun yang baru terdengar di RF yang diteruskan. Bila mati, hanya RF→IS.';

  @override
  String get igateStatToIs => 'Diteruskan → APRS-IS';

  @override
  String get igateStatToRf => 'Diteruskan → RF';

  @override
  String get igateStatDup => 'Duplikat dibuang';

  @override
  String get igateResetStats => 'Reset penghitung';

  @override
  String get igateStatRfSeen => 'Diterima di RF';

  @override
  String get igateStatBlocked => 'Ditolak proteksi loop';

  @override
  String get igateRfDown =>
      'Tautan RF terputus, gateway tidak dapat meneruskan apa pun. Jika “Diterima di RF” tetap 0, paket tidak sampai — periksa status TNC/audio (baud serial, perangkat menyala), bukan gateway-nya.';

  @override
  String get igateIsDown =>
      'APRS-IS belum terhubung, gateway tidak punya tujuan penerusan. Penghitung baru bergerak setelah tersambung (lihat kartu status tautan).';

  @override
  String get igateNoRfTraffic =>
      'Tidak ada paket yang terdengar di RF: kondisi gateway sudah lengkap tetapi **tidak ada yang diteruskan**. Ini bukan masalah gateway — paket tidak sampai ke aplikasi. Periksa hulu: volume dan squelch radio, antena, apakah ada yang benar-benar memancar, dan halaman log untuk lalu lintas RF apa pun.';

  @override
  String get igateAllRejected =>
      'Paket RF diterima tetapi semuanya ditolak proteksi loop: membawa TCPIP*/TCPXX* atau q-construct, artinya berasal dari internet, dan mengirimnya kembali akan memperbanyak paket yang sama. Ini **bekerja dengan benar**, bukan kerusakan.';

  @override
  String grpSysJoined(String call) {
    return '$call bergabung ke grup';
  }

  @override
  String grpSysLeft(String call) {
    return '$call keluar dari grup';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call meminta bergabung';
  }

  @override
  String grpSysDeclined(String call) {
    return '$call menolak undangan';
  }

  @override
  String get grpInviteTitle => 'Undangan grup';

  @override
  String grpInviteBody(String from, String name) {
    return '$from mengundang Anda ke \"$name\"';
  }

  @override
  String get grpNameInvalid =>
      'Nama grup tidak boleh kosong atau berisi titik dua/baris baru';

  @override
  String grpNameTooLong(int max) {
    return 'Nama grup maksimal $max karakter (lebih panjang membuat undangan melebihi batas pesan APRS)';
  }

  @override
  String grpInviteSent(int n) {
    return 'Undangan dikirim ke $n anggota';
  }

  @override
  String get grpSelfPending => 'Menunggu pemilik grup';

  @override
  String get deviceOverviewTitle => 'Perangkat';

  @override
  String get deviceOverviewSubtitle =>
      'Sumber data, status tautan, dan uji mandiri';

  @override
  String get deviceCurrentLink => 'Tautan saat ini';

  @override
  String get deviceCurrentLinkDesc =>
      'Ringkasan hanya-baca — ubah parameter di sub-halaman';

  @override
  String get deviceEntries => 'Perangkat & parameter';

  @override
  String get deviceEntriesDesc =>
      'Satu sub-halaman per tautan, setelannya masing-masing';

  @override
  String get tncDeviceTitle => 'Perangkat & parameter TNC';

  @override
  String get tncDeviceDesc =>
      'Binding Bluetooth/serial, string init, parameter KISS, uji pancar';

  @override
  String get deviceLogTitle => 'Log tautan';

  @override
  String get deviceLogDesc =>
      'Menampilkan log sumber saat ini (TNC / audio otomatis)';

  @override
  String get tncInitTitle => 'String init TNC';

  @override
  String get tncInitSubtitle =>
      'Dikirim baris demi baris setelah terhubung (setara kiss.init APRSdroid)';

  @override
  String get tncInitTip =>
      'Bila TNC menerima tetapi tidak memancar, coba di sini dulu: banyak modul TNC Bluetooth/serial menyala dalam mode perintah dan perlu KISS ON / RESTART agar mau meneruskan dalam KISS. Satu perintah per baris (CRLF ditambahkan otomatis).';

  @override
  String get tncInitDelay => 'Jeda per baris (ms)';

  @override
  String get tncInitDelayTip =>
      'Jeda antar baris. Modul butuh waktu memproses perintah; terlalu singkat bisa terlewat';

  @override
  String get tncInitSendAction => 'Kirim string init sekarang';

  @override
  String tncInitSent(int n) {
    return '$n baris init terkirim';
  }

  @override
  String get tncInitEmpty => 'String init belum diisi';

  @override
  String get tncPushParams => 'Kirim parameter KISS saat terhubung';

  @override
  String get tncPushParamsTip =>
      'Mati secara bawaan (sama seperti APRSdroid). Bila aktif, nilai di atas dikirim ke TNC saat terhubung dan menimpa konfigurasinya — nilai yang tidak cocok bisa membuatnya terus menunggu tanpa memancar, jadi aktifkan hanya bila ingin dikelola terpusat.';

  @override
  String get tncTxTestTitle => 'Uji pancar';

  @override
  String get tncTxTestSubtitle =>
      'Menulis satu bingkai uji ke TNC untuk memisahkan masalah tautan vs TNC';

  @override
  String get tncTxTestHint =>
      'Yang dikirim adalah bingkai status (tanpa koordinat), jadi tidak memindahkan stasiun Anda di aprs.fi. Bila tertulis \"tertulis\" tetapi tetap tidak memancar, masalahnya di sisi TNC: coba string init (KISS ON / RESTART) dulu, lalu periksa TxDelay dan okupansi kanal.';

  @override
  String get tncTxTestAction => 'Tulis bingkai uji';

  @override
  String get tncTxTestOkPrefix => 'Tertulis';

  @override
  String tncTxTestOk(String n) {
    return 'Tertulis ke TNC (total $n bingkai). Bila radio tetap tidak memancar, masalahnya di sisi TNC: coba string init atau periksa TxDelay.';
  }

  @override
  String tncTxTestFail(String err) {
    return 'Tidak tertulis: $err';
  }

  @override
  String get tncNeedConnected => 'Hubungkan TNC dulu';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 karakter · total $bytes/512 byte';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return 'Pesan ini $chars karakter, melebihi batas spesifikasi APRS yaitu 67. Sebagian besar klien masih bisa menampilkannya, tetapi sebagian klien/gateway memotong atau menolaknya, sehingga stasiun lawan mungkin tidak dapat mengurainya. Tetap kirim?';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return 'Paket berukuran $bytes byte, melebihi batas 512 byte per baris APRS-IS. Server mungkin membuang seluruh paket (bahkan header tidak sampai). Mohon perpendek sekitar $over byte.';
  }

  @override
  String get msgSendAnyway => 'Tetap kirim';

  @override
  String get msgSpecLimitHint =>
      'Spesifikasi APRS menyarankan pesan di bawah 67 karakter: teks yang lebih panjang dapat terpotong atau gagal diurai di sebagian klien.';

  @override
  String get msgBlockedTooLong =>
      'Pengiriman diblokir: paket melebihi batas APRS-IS';

  @override
  String get beaconRfBeaconOff => 'Beacon RF mati';

  @override
  String get beaconRfEnableHint =>
      'Pemancaran otomatis pada sumber RF memerlukan sakelar \"Beacon RF\". Sebelum itu posisi tidak dipancarkan otomatis (hitung mundur juga tidak berjalan).';

  @override
  String get beaconRfEnableAction => 'Aktifkan beacon RF';

  @override
  String get beaconRfEnabled => 'Beacon RF aktif — akan memancar sesuai jadwal';

  @override
  String get beaconRfEnableWarn =>
      'Pemancaran memakai tanda panggil Anda — patuhi lisensi';

  @override
  String get diagTitle => 'Uji mandiri tautan';

  @override
  String get diagSubtitle =>
      'Memeriksa protokol, izin, dan perangkat lapis demi lapis';

  @override
  String get diagRun => 'Jalankan uji';

  @override
  String get diagRunning => 'Menguji…';

  @override
  String diagPassed(int n) {
    return '$n lulus';
  }

  @override
  String diagFailed(int n) {
    return '$n gagal';
  }

  @override
  String get diagHint =>
      'Uji protokol bisa jalan tanpa radio: pastikan perangkat lunak dulu, lalu cek perangkat dan kabel';

  @override
  String get diagTncSection => 'TNC (KISS / AX.25)';

  @override
  String get diagAudioSection => 'Audio (AFSK 1200)';

  @override
  String get diagKissEscape => 'Escape KISS';

  @override
  String get diagKissEscapeFail =>
      'Gagal membalik escape KISS (masalah perangkat lunak — ganti perangkat tidak membantu)';

  @override
  String get diagAx25 => 'Pembingkaian AX.25';

  @override
  String get diagAx25Fail => 'Pengodean AX.25 gagal (format paket salah)';

  @override
  String diagAx25Mismatch(String got) {
    return 'Hasil bolak-balik AX.25 tidak cocok: $got';
  }

  @override
  String get diagFcs => 'Pemeriksaan FCS';

  @override
  String get diagFcsFail =>
      'Pemeriksaan FCS salah (perubahan satu byte harus ditolak)';

  @override
  String get diagTncLoopback => 'Loop protokol TNC';

  @override
  String diagTncLoopbackOk(int len) {
    return 'Bolak-balik KISS/AX.25 identik ($len byte)';
  }

  @override
  String get diagAfskLoopback => 'Loop modem AFSK';

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return 'Modulasi → demodulasi identik ($samples sampel @${rate}Hz)';
  }

  @override
  String diagAfskLoopbackFail(int n) {
    return '$n bingkai terdekode — seharusnya 1';
  }

  @override
  String get diagAfskLevelFail =>
      'Level gelombang terlalu rendah (hampir senyap)';

  @override
  String get diagPlatform => 'Dukungan platform';

  @override
  String diagPlatformOk(String name) {
    return 'Tersedia · backend $name';
  }

  @override
  String get diagTncPlatformNo => 'Tautan TNC tidak didukung di platform ini';

  @override
  String get diagAudioPlatformWarn =>
      'Tanpa audio waktu-nyata — mode berkas WAV tetap tersedia';

  @override
  String get diagNoRealtime => 'bukan waktu-nyata';

  @override
  String get diagPermission => 'Izin mikrofon';

  @override
  String get diagPermissionOk => 'Diberikan';

  @override
  String get diagSkipped => 'Dilewati (platform tidak didukung)';

  @override
  String get diagCapture => 'Penangkapan audio';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return 'Menerima $bytes byte @${rate}Hz';
  }

  @override
  String get diagCaptureNoData =>
      'Tidak ada data audio — periksa perangkat masukan dan izin';

  @override
  String diagCaptureFailed(String err) {
    return 'Gagal memulai penangkapan: $err';
  }

  @override
  String get diagSpeaker => 'Keluaran speaker';

  @override
  String get diagSpeakerOk => 'Nada uji diputar';

  @override
  String diagSpeakerFail(String err) {
    return 'Pemutaran gagal: $err';
  }

  @override
  String get diagFileIo => 'I/O berkas WAV';

  @override
  String diagFileIoOk(int rate) {
    return 'Tulis → baca → dekode identik @${rate}Hz';
  }

  @override
  String diagFileWriteFail(String err) {
    return 'Gagal menulis berkas: $err';
  }

  @override
  String get diagFileReadFail => 'Gagal membaca berkas';

  @override
  String get diagFileDecodeFail =>
      'Tidak ada paket terdekode dari berkas (mungkin bukan rekaman AFSK 1200)';

  @override
  String get connAudioSourceHint =>
      'Mode audio tidak memakai server, filter, atau setelan KISS';

  @override
  String get testTxTitle => 'Uji pancar';

  @override
  String get testTxDesc =>
      'Mengirim paket status untuk membuktikan tautan benar-benar ke udara';

  @override
  String get testTxAction => 'Pancarkan bingkai uji';

  @override
  String get testTxSent => 'Bingkai uji diberikan ke tautan';

  @override
  String testTxFail(String err) {
    return 'Bingkai uji gagal: $err';
  }

  @override
  String get testTxNeedsConnect => 'Hubungkan tautan dulu';

  @override
  String get testTxHint =>
      'Ini **benar-benar memancar** (paket status, tanpa koordinat). Pastikan sesuai lisensi dan tanda panggil Anda';

  @override
  String get audioStatsTitle => 'Statistik audio';

  @override
  String audioStatRx(int n) {
    return '$n bingkai diterima';
  }

  @override
  String audioStatTx(int n) {
    return '$n bingkai terkirim';
  }

  @override
  String audioStatDrop(int n) {
    return '$n byte dibuang saat memancar';
  }

  @override
  String get audioRestart => 'Mulai ulang tautan audio';

  @override
  String get audioTxDisabled => '\"Izinkan pancar\" mati — hanya menerima';

  @override
  String get audioLoopbackHint =>
      'Pemeriksaan benar-benar melakukan modulasi→demodulasi; di Android mikrofon dijeda saat mengirim (half duplex)';

  @override
  String get notifAudioConnected => 'Tautan audio aktif';

  @override
  String get notifAudioDisconnected => 'Tautan audio terputus';

  @override
  String connConnectingAudio(String name) {
    return 'Membuka audio ($name)…';
  }

  @override
  String connAudioConnected(String rate) {
    return 'Tautan audio aktif · $rate';
  }

  @override
  String connRetryAudio(int seconds) {
    return 'Gagal membuka audio · coba lagi dalam ${seconds}s…';
  }

  @override
  String connRetryAudioDetail(String detail, int seconds) {
    return 'Audio gagal ($detail) · coba lagi dalam ${seconds}s…';
  }

  @override
  String connAudioLinkLost(int seconds) {
    return 'Tautan audio terputus · menyambung ulang dalam ${seconds}s…';
  }

  @override
  String connAudioPositionSent(String call) {
    return 'Terkirim via audio · posisi terkirim ($call)';
  }

  @override
  String get dataSourceAudio => 'Audio (kartu suara)';

  @override
  String get dataSourceAudioDesc =>
      'AFSK 1200 ke/dari radio lewat mic/speaker atau kabel kartu suara';

  @override
  String get audioSettings => 'Audio (TNC kartu suara)';

  @override
  String get audioSettingsSubtitle =>
      'Kirim/terima paket AFSK 1200 dengan kartu suara';

  @override
  String get audioBackend => 'Backend audio';

  @override
  String get audioUnsupported =>
      'Audio waktu-nyata tidak didukung di platform ini (mode berkas WAV tersedia)';

  @override
  String get audioNeedPermission =>
      'Izin mikrofon (RECORD_AUDIO) diperlukan — berikan lalu coba lagi';

  @override
  String get audioCaptureTitle => 'Penangkapan audio';

  @override
  String get audioCaptureDesc => 'Demodulasi AFSK 1200 dari masukan mic/line';

  @override
  String get audioCaptureStart => 'Mulai tangkap';

  @override
  String get audioCaptureStop => 'Hentikan';

  @override
  String get audioSampleRate => 'Laju sampel';

  @override
  String get audioSampleRateTip =>
      '22050Hz adalah nilai umum TNC kartu suara; pakai 44100/48000 bila tidak didukung. Mengubahnya memulai ulang penangkapan';

  @override
  String get audioLevel => 'Level masukan';

  @override
  String get audioLevelTip =>
      'Meter naik saat ada sinyal; \"Demod terkunci\" menyala saat AFSK terdeteksi';

  @override
  String get audioSynced => 'Demod terkunci';

  @override
  String get audioUnlocked => 'Tidak terkunci';

  @override
  String audioBadFrames(int n) {
    return '$n dekode dibatalkan (derau/kehilangan sinkron)';
  }

  @override
  String get audioBaud => 'Laju bit';

  @override
  String get audioTones => 'Nada (mark/space)';

  @override
  String get audioTxTitle => 'Pemancaran audio';

  @override
  String get audioTxDesc =>
      'Mendengarkan sebelum memancar untuk menghindari tabrakan';

  @override
  String get audioTxEnabled => 'Izinkan pancar';

  @override
  String get audioTxEnabledTip =>
      'Jika mati, hanya menerima — praktis bila hanya ingin memantau beacon';

  @override
  String get audioTxDelayTip =>
      'Panjang preamble: memberi waktu demod lawan mengunci dan PTT radio aktif';

  @override
  String get audioToneMark => 'Nada mark (Hz)';

  @override
  String get audioToneSpace => 'Nada space (Hz)';

  @override
  String get audioMarkTip =>
      'Bell 202 menetapkan mark 1200Hz / space 2200Hz; toleransinya hanya beberapa Hz';

  @override
  String get audioSpaceTip =>
      'Nada space. Bersama mark menentukan shift FSK (nominal 1000Hz)';

  @override
  String get audioBaudTip =>
      'APRS di VHF selalu 1200 bd (Bell 202); 300 untuk HF';

  @override
  String get audioTxDelayLabel => 'Preamble Tx (ms)';

  @override
  String get audioTnc2Tip =>
      'Format SRC>DEST,PATH:info, mis. BG7LZQ-9>APALOC:>TEST';

  @override
  String get audioCsmaWait => 'Tunggu kanal bebas (ms)';

  @override
  String get audioCsmaWaitTip =>
      'Berapa lama menunggu saat kanal sibuk; 0 = langsung pancar';

  @override
  String get audioStopTx => 'Hentikan pancar';

  @override
  String get audioWavTitle => 'Mode berkas WAV';

  @override
  String get audioWavDesc =>
      'Dekode rekaman secara offline, atau ekspor paket sebagai audio';

  @override
  String get audioWavPath => 'Jalur berkas';

  @override
  String get audioWavDecodeAction => 'Dekode WAV ini';

  @override
  String get audioWavExportAction => 'Ekspor paket ini';

  @override
  String get audioWavTnC2 => 'Paket untuk ekspor (TNC2)';

  @override
  String get audioWavNone =>
      'Tidak ada paket terdekode (mungkin bukan rekaman AFSK 1200)';

  @override
  String audioWavFound(int n) {
    return '$n paket terdekode';
  }

  @override
  String audioWavWritten(String path) {
    return 'Ditulis ke $path';
  }

  @override
  String audioWavFailed(String err) {
    return 'Gagal baca/tulis berkas: $err';
  }

  @override
  String connTncConnected(String arg) {
    return 'TNC terhubung · $arg';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC terhubung · posisi terkirim ($arg)';
  }

  @override
  String connRetryTnc(int n) {
    return 'Koneksi TNC gagal · mencoba lagi dalam ${n}s…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'Koneksi TNC gagal ($e) · mencoba lagi dalam ${n}s…';
  }

  @override
  String connTncLinkLost(int n) {
    return 'Tautan TNC terputus · menyambung ulang dalam ${n}s…';
  }

  @override
  String get tncErrNoDevice => 'belum ada perangkat TNC';

  @override
  String get tncErrUnsupported => 'tidak didukung di platform ini';

  @override
  String get tncErrNotConnected => 'tautan belum tersambung';

  @override
  String get tncErrOpenRead => 'tidak bisa membuka perangkat untuk membaca';

  @override
  String get tncErrOpenWrite =>
      'tidak bisa membuka perangkat untuk menulis — port COM Windows bersifat eksklusif; periksa aplikasi lain';

  @override
  String get tncErrBadFormat => 'paket tidak valid';

  @override
  String get tncErrFrameTooLong => 'bingkai melebihi batas ukuran';

  @override
  String get tncErrTimeout => 'waktu habis';

  @override
  String get translateMyLang => 'Bahasa saya';

  @override
  String get translateMyLangHint =>
      'Pesan dari lawan bicara diterjemahkan ke bahasa ini';

  @override
  String get translatePeerLang => 'Bahasa lawan bicara';

  @override
  String get translatePeerUnknownHint => 'Dikenali otomatis dari pesan mereka';

  @override
  String get translateLearned => 'Terdeteksi otomatis';

  @override
  String get translatePeerUnknown =>
      'Bahasa lawan bicara belum diketahui — atur di pengaturan terjemahan, atau akan terdeteksi setelah beberapa pesan mereka';

  @override
  String get translateSideIncoming => 'diterima';

  @override
  String get translateSideOutgoing => 'terkirim';

  @override
  String get translateToMeTag => 'untuk saya';

  @override
  String get translateToPeerTag => 'yang mereka baca';

  @override
  String get translateContrast => 'Tampilkan asli dan terjemahan bersama';

  @override
  String get translateContrastTip =>
      'Jika mati hanya terjemahan yang tampil (aslinya lewat tekan lama)';

  @override
  String get translateProviderFree => 'Gratis (tanpa kunci)';

  @override
  String get translateProviderFreeDesc =>
      'Langsung pakai · memakai endpoint publik yang bisa dibatasi atau tidak stabil';

  @override
  String translateFreeFailed(String e) {
    return 'Endpoint gratis sedang tidak tersedia ($e) · ganti ke Google / Baidu / kustom di pengaturan';
  }

  @override
  String get translateProviderAuto => 'Otomatis (disarankan)';

  @override
  String get translateProviderAutoDesc =>
      'Mencoba beberapa endpoint tanpa kunci dan memakai hasil terjemahan pertama yang válid';

  @override
  String get translateProviderGooglePublic =>
      'Endpoint publik Google (tanpa kunci)';

  @override
  String get translateProviderGooglePublicDesc =>
      'Kualitas baik, tetapi bisa dibatasi (teramati 429)';

  @override
  String get translateProviderMyMemory => 'MyMemory (tanpa kunci)';

  @override
  String get translateProviderMyMemoryDesc =>
      'API gratis resmi, tetapi berupa memori terjemahan: mengembalikan teks asli bila tidak ada kecocokan';

  @override
  String get translateProviderLibre => 'LibreTranslate (bisa self-host)';

  @override
  String get translateProviderLibreDesc =>
      'Open source; paling andal bila di-self-host. Instans publik kini butuh kunci dan sering tanpa bahasa Tionghoa';

  @override
  String get translateLibreUrl => 'URL instans';

  @override
  String get translateLibreKey =>
      'Kunci API instans (perlu untuk publik; kosongkan bila self-host)';

  @override
  String get translateUsedProvider => 'Yang dipakai';

  @override
  String get translateUntranslated =>
      'Endpoint tidak benar-benar menerjemahkan (mengembalikan teks asli) — mencoba yang berikutnya';

  @override
  String translateAutoAllFailed(String e) {
    return 'Semua endpoint tanpa kunci gagal ($e) · beralih ke kunci Google/Baidu atau instans sendiri di pengaturan';
  }

  @override
  String get translateLangUnsupported =>
      'Penyedia ini tidak bisa menerjemahkan ke bahasa itu · coba “Otomatis” atau penyedia lain';

  @override
  String get translateLangScopeNote =>
      'Cakupan bahasa tiap penyedia berbeda (mis. Baidu standar mendukung bahasa Indonesia “id”, tetapi tidak semua arah) — bila tidak didukung, aplikasi menyarankan Otomatis atau penyedia lain';

  @override
  String get langNameZh => 'Tionghoa Sederhana';

  @override
  String get langNameZhTw => 'Tionghoa Tradisional';

  @override
  String get langNameEn => 'Inggris';

  @override
  String get langNameJa => 'Jepang';

  @override
  String get langNameKo => 'Korea';

  @override
  String get langNameEs => 'Spanyol';

  @override
  String get langNameFr => 'Prancis';

  @override
  String get langNameDe => 'Jerman';

  @override
  String get langNameRu => 'Rusia';

  @override
  String get langNamePt => 'Portugis';

  @override
  String get langNameIt => 'Italia';

  @override
  String get langNameId => 'Indonesia';

  @override
  String get langNameTh => 'Thai';

  @override
  String get langNameVi => 'Vietnam';

  @override
  String get langNameAr => 'Arab';

  @override
  String get translateOutgoing =>
      'Terjemahkan ke bahasa mereka sebelum mengirim';

  @override
  String get translateOutgoingTip =>
      'Jika aktif, teks diterjemahkan ke bahasa mereka sebelum dikirim — pastikan mereka bisa membacanya';

  @override
  String get translateInput => 'Terjemahkan isi';

  @override
  String translateOutPreview(String text) {
    return 'Akan dikirim: $text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return 'Diterjemahkan ke $lang · ketuk kirim untuk mengirim ini';
  }

  @override
  String get translateOutCancel => 'Batalkan terjemahan';

  @override
  String get translateOutNeedPeer =>
      'Bahasa mereka belum diketahui — atur di pengaturan terjemahan percakapan';

  @override
  String translateSentAs(String text) {
    return 'Dikirim dalam bahasa mereka: $text';
  }

  @override
  String translateTooLongAfter(int n) {
    return 'Terjemahan melebihi batas panjang ($n karakter) — tidak dikirim';
  }

  @override
  String get dateToday => 'Hari ini';

  @override
  String get dateYesterday => 'Kemarin';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$d/$m/$y $w';
  }

  @override
  String dateWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': 'Sen',
      '2': 'Sel',
      '3': 'Rab',
      '4': 'Kam',
      '5': 'Jum',
      '6': 'Sab',
      '7': 'Min',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get translate => 'Terjemahkan';

  @override
  String get translateText => 'Terjemahkan teks';

  @override
  String get translateSettings => 'Pengaturan terjemahan';

  @override
  String get translateSettingsSubtitle =>
      'Penyedia, bahasa, dan terjemahan otomatis';

  @override
  String get translateProvider => 'Penyedia';

  @override
  String get translateProviderGoogle => 'Google Terjemahan';

  @override
  String get translateProviderBaidu => 'Baidu Terjemahan';

  @override
  String get translateProviderCustom => 'Kustom';

  @override
  String get translateGoogleKey => 'Kunci API Google';

  @override
  String get translateGoogleKeyTip =>
      'Kunci API untuk Google Cloud Translation v2 — buat di konsol Google Cloud';

  @override
  String get translateBaiduAppId => 'App ID Baidu';

  @override
  String get translateBaiduKey => 'Kunci rahasia Baidu';

  @override
  String get translateBaiduTip =>
      'Ajukan terjemahan teks umum di platform Baidu Translate; kunci hanya disimpan di perangkat ini';

  @override
  String get translateCustomUrl => 'URL endpoint';

  @override
  String get translateCustomMethod => 'Metode HTTP';

  @override
  String get translateCustomHeaders => 'Header (JSON)';

  @override
  String get translateCustomBody => 'Templat body';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return 'Placeholder: $text, $from, $to. Diabaikan bila metode GET';
  }

  @override
  String get translateCustomResultPath => 'Jalur JSON hasil';

  @override
  String get translateCustomResultPathTip =>
      'Jalur dengan titik dan indeks larik, mis. data.translations.0.translatedText';

  @override
  String get translateTest => 'Uji terjemahan';

  @override
  String translateTestOk(String text) {
    return 'Penyedia berfungsi: $text';
  }

  @override
  String get translateNeedConfig =>
      'Konfigurasikan penyedia terjemahan lebih dulu';

  @override
  String translateFailed(String e) {
    return 'Terjemahan gagal: $e';
  }

  @override
  String get translateTargetLang => 'Terjemahkan ke';

  @override
  String get translateSourceLang => 'Bahasa sumber';

  @override
  String get translateAuto => 'Terjemahkan pesan masuk otomatis';

  @override
  String get translateAutoTip =>
      'Berlaku hanya untuk percakapan ini; hanya menerjemahkan pesan masuk';

  @override
  String get translateShowOriginal => 'Tampilkan asli';

  @override
  String get translateShowTranslation => 'Tampilkan terjemahan';

  @override
  String get translateRetry => 'Terjemahkan ulang';

  @override
  String get translateTranslating => 'Menerjemahkan…';

  @override
  String get translateCopyOriginal => 'Salin asli';

  @override
  String get translateCopyResult => 'Salin terjemahan';

  @override
  String get translateLangAuto => 'Deteksi otomatis';

  @override
  String get translateSameLang =>
      'Terjemahan sama dengan aslinya · mungkin tidak perlu diterjemahkan, atau penyedia gagal';

  @override
  String get translateNotNeeded =>
      'Tidak ada yang perlu diterjemahkan (angka / simbol / tanda panggil)';

  @override
  String translateBubbleCount(int n) {
    return '$n diterjemahkan';
  }

  @override
  String get translatePrivacyNote =>
      'Terjemahan mengirim teks pesan ke penyedia pihak ketiga pilihan Anda; pertimbangkan privasi';

  @override
  String get notifTncConnected => 'TNC terhubung';

  @override
  String get notifTncDisconnected => 'TNC terputus';

  @override
  String get dataSourceTitle => 'Sumber data';

  @override
  String get dataSourceSubtitle => 'Dari mana paket berasal';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => 'Jaringan APRS global lewat internet';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc =>
      'Kirim dan terima lewat udara via TNC Bluetooth atau serial';

  @override
  String get dataSourceSwitchHint =>
      'Mengganti sumber data akan memutus koneksi saat ini';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL (waypoint Kenwood)';

  @override
  String get dataSourcePkwdwplDesc =>
      'Baca kalimat waypoint Kenwood \$PKWDWPL dari radio lewat Bluetooth/serial (hanya terima)';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL adalah tautan **hanya terima**: menerima stasiun tetapi tidak pernah memancar (gunakan APRS-IS / TNC / audio untuk memancar)';

  @override
  String connConnectingPkwdwpl(String arg) {
    return 'Menghubungkan PKWDWPL ($arg)…';
  }

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL terhubung · $arg';
  }

  @override
  String get pkwdwplDeviceTitle => 'Perangkat PKWDWPL';

  @override
  String get pkwdwplDeviceDesc =>
      'Pasangkan port radio dan lihat status penerimaan waypoint';

  @override
  String get pkwdwplBindTitle => 'Pemasangan perangkat dan status';

  @override
  String get pkwdwplBindSubtitle =>
      'Pilih port serial atau Bluetooth yang mengeluarkan kalimat \$PKWDWPL';

  @override
  String get pkwdwplRxOnly => 'Hanya terima';

  @override
  String get pkwdwplReadOnly =>
      'Hanya terima · perangkat ini tidak memancarkan apa pun';

  @override
  String get deviceConflictTitle => 'Dua tautan terikat ke perangkat yang sama';

  @override
  String get deviceConflictDesc =>
      'Bila TNC dan PKWDWPL menunjuk perangkat yang sama, data terima dibagi antara keduanya — gejalanya \"bisa kirim tetapi tidak bisa terima\". Gantilah salah satunya ke perangkat lain. TNC diprioritaskan: PKWDWPL akan menolak terhubung.';

  @override
  String get deviceInUseByTnc => 'Sedang dipakai TNC — tidak bisa diikat lagi';

  @override
  String get deviceInUseByPkwdwpl =>
      'Sedang dipakai PKWDWPL — tidak bisa diikat lagi';

  @override
  String rxOnlyBanner(String arg) {
    return '$arg terhubung · hanya terima (sumber kirim belum aktif)';
  }

  @override
  String get pkwdwplTip =>
      'Setel format keluaran port PC / GPS di radio ke \"\$PKWDWPL\" (biasanya 4800 8N1). Tautan ini hanya baca dan tidak memancarkan apa pun.';

  @override
  String get pkwdwplStrictChecksum => 'Checksum ketat (buang jika tidak cocok)';

  @override
  String get pkwdwplStrictChecksumTip =>
      'Nonaktif secara bawaan: ketidakcocokan hanya ditandai dan dicatat, tidak dibuang, karena pada kabel lokal hal ini biasanya berarti format firmware berbeda dari manual. Membuang semuanya akan membuat layar kosong dan jauh lebih sulit ditelusuri.';

  @override
  String get pkwdwplErrReadOnly => 'tautan hanya terima tidak dapat memancar';

  @override
  String get pkwdwplStatTitle => 'Penerimaan waypoint';

  @override
  String pkwdwplStats(String rx) {
    return '$rx waypoint diterima';
  }

  @override
  String get pkwdwplStatRejected => 'Kalimat dibuang atau tidak valid';

  @override
  String get pkwdwplStatMismatch => 'Ketidakcocokan checksum';

  @override
  String get pkwdwplStatIgnored => 'Kalimat NMEA lain (diabaikan)';

  @override
  String get pkwdwplLogEmpty => 'Belum ada log PKWDWPL';

  @override
  String get tncBindTitle => 'TNC Bluetooth';

  @override
  String get tncBindSubtitle => 'Pasangkan dan hubungkan TNC di radio Anda';

  @override
  String get tncBoundDevice => 'Perangkat terpasang';

  @override
  String get tncNotBound => 'Belum ada perangkat';

  @override
  String get tncScanPaired =>
      'Pindai perangkat (Bluetooth tertaut + serial USB)';

  @override
  String get tncNoPaired =>
      'Perangkat tidak ditemukan — tautkan TNC di pengaturan Bluetooth sistem, atau colokkan kabel serial USB (OTG)';

  @override
  String get tncUnbind => 'Lepas';

  @override
  String get tncConnectAction => 'Hubungkan TNC';

  @override
  String get tncRestart => 'Mulai ulang tautan';

  @override
  String get tncSupportedNo => 'Tautan TNC belum didukung di platform ini';

  @override
  String get tncNeedPermission =>
      'Izin Bluetooth diperlukan untuk memindai perangkat Bluetooth; abaikan jika hanya memakai serial USB — sistem memintanya sendiri saat kabel dicolokkan';

  @override
  String get tncOpenFailedHint =>
      'Gagal membuka perangkat — port COM Windows bersifat eksklusif; pastikan tidak dipakai aplikasi lain';

  @override
  String tncStats(String rx, String tx) {
    return '$rx bingkai diterima · $tx terkirim';
  }

  @override
  String get tncLog => 'Log tautan';

  @override
  String get tncLogEmpty => 'Belum ada log';

  @override
  String get kissParamsTitle => 'Parameter KISS';

  @override
  String get kissParamsSubtitle =>
      'Pengaturan lapisan tautan yang dikirim langsung ke TNC';

  @override
  String get kissTxDelay => 'Tunda TX (ms)';

  @override
  String get kissTxDelayTip =>
      'KISS TXDELAY dalam satuan 10 ms — waktu PTT sebelum data dikirim';

  @override
  String get kissTxTail => 'Ekor TX (ms)';

  @override
  String get kissTxTailTip =>
      'KISS TXTAIL dalam satuan 10 ms — sebagian radio perlu ekor agar terdengar utuh';

  @override
  String get kissPersistence => 'Persistensi';

  @override
  String get kissPersistenceTip =>
      'KISS PERSISTENCE, 0–255 — makin kecil makin sopan dan mengurangi tabrakan di kanal bersama';

  @override
  String get kissSlotTime => 'Waktu slot (ms)';

  @override
  String get kissSlotTimeTip =>
      'KISS SLOTTIME dalam satuan 10 ms — bekerja bersama persistensi mengatur akses kanal';

  @override
  String get kissFullDuplex => 'Dupleks penuh';

  @override
  String get kissFullDuplexTip =>
      'KISS FULLDUPLEX — matikan untuk radio biasa (TX/RX bersamaan saling mengganggu)';

  @override
  String get kissChannel => 'Kanal / porta KISS';

  @override
  String get kissChannelTip =>
      'Hanya TNC multikanal punya beberapa port; biarkan 0 untuk radio satu kanal';

  @override
  String get kissMaxFrame => 'Ukuran bingkai maks (bita)';

  @override
  String get kissMaxFrameTip =>
      'Paket yang lebih panjang tidak dikirim (pada 1200 baud bingkai AX.25 sekitar 330 bita)';

  @override
  String get kissHardwareCmd => 'Perintah vendor';

  @override
  String get kissHardwareVal => 'Nilai';

  @override
  String get kissHardwareTip =>
      'KISS SETHARDWARE (0x06), khusus vendor; -1 berarti tidak dikirim';

  @override
  String get kissApplyParams => 'Kirim parameter';

  @override
  String get kissParamsSent => 'Parameter KISS terkirim';

  @override
  String get kissBackToCommand => 'Kembali ke mode perintah TNC';

  @override
  String get kissBackToCommandTip =>
      'Mengirim RETURN (0x0F). Sebagian besar TNC KISS berhenti meneruskan sampai tautan dimulai ulang';

  @override
  String get kissRfPath => 'Jalur digipeater RF';

  @override
  String get kissRfPathTip =>
      'Digipeater yang dipakai di udara, mis. WIDE1-1,WIDE2-1; kosongkan bila tidak perlu';

  @override
  String get kissRfBeacon => 'Izinkan beacon RF';

  @override
  String get kissRfBeaconTip =>
      'Hanya setelah aktif posisi dikirim lewat udara. Memancar memerlukan lisensi dan tanda panggil Anda';

  @override
  String get kissAutoAck => 'ACK otomatis';

  @override
  String get kissAutoAckTip =>
      'Jika mati, pesan masuk tidak di-ACK — kanal lebih sepi';

  @override
  String get kissAutoReconnect => 'Sambung ulang otomatis';

  @override
  String get kissNeedConnected => 'Hubungkan TNC lebih dulu';

  @override
  String get tncSwitchOn => 'Aktif';

  @override
  String get tncSwitchOff => 'Nonaktif';

  @override
  String get connTncSourceHint =>
      'Mode TNC tidak memakai server atau filter, jadi pengaturan itu dinonaktifkan';

  @override
  String get connectTncBar => 'Ketuk Hubungkan untuk membuka tautan TNC';

  @override
  String connectingToTnc(String name) {
    return 'Menghubungkan TNC · $name';
  }

  @override
  String get tncMsgTitle => 'Mode radio (TNC)';

  @override
  String get tncMsgDesc =>
      'Kanal radio dipakai bersama, jadi perpesanan dibatasi';

  @override
  String get tncGroupDisabled => 'Siaran grup tidak tersedia di mode radio';

  @override
  String tncMsgLimitHint(String n) {
    return '$n karakter per pesan (spesifikasi APRS)';
  }

  @override
  String get tncMsgTooLong => 'Melebihi batas panjang pesan untuk mode radio';

  @override
  String get licenseSection => 'Lisensi';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      'Perangkat lunak ini dirilis di bawah lisensi GNU GPL v3. Anda boleh menjalankan, mempelajari, memodifikasi, dan mendistribusikan ulang selama mematuhi ketentuan lisensi; versi modifikasi dan redistribusi wajib mematuhi kewajiban GPL v3 yang berlaku. Perangkat lunak ini disediakan tanpa jaminan apa pun.';

  @override
  String get licenseText => 'Lihat lisensi';

  @override
  String get oobeAgreeTitle => 'Perjanjian Pengguna & Lisensi';

  @override
  String get oobeAgreeBody =>
      'Selamat datang di APRSlocus! Bacalah dan setujui ketentuan berikut sebelum menggunakan aplikasi. Perlu diketahui: data APRS bersifat publik — setelah dikirim, data dapat diterima, disimpan, dan diteruskan oleh jaringan APRS sedunia.';

  @override
  String get oobeAgreeCheck =>
      'Saya telah membaca dan menyetujui Perjanjian Pengguna dan lisensi GPL-3.0';

  @override
  String get oobeAgreeNeed =>
      'Baca dan centang persetujuan Perjanjian Pengguna terlebih dahulu';

  @override
  String get oobeDeclineExit => 'Tolak dan keluar';

  @override
  String get userAgreement => 'Perjanjian Pengguna';

  @override
  String get beaconWarnTitle => 'Interval beacon terlalu pendek';

  @override
  String get beaconWarnBody =>
      'APRS-IS menyarankan interval beacon minimal 60 detik untuk stasiun bergerak. Pengiriman yang terlalu sering dapat dianggap penyalahgunaan dan menyebabkan koneksi diputus server. Tetap gunakan interval ini?';

  @override
  String get beaconWarnKeep => 'Tetap gunakan';

  @override
  String get beaconWarnFix => 'Kembalikan ke 60 dtk';

  @override
  String get features => 'Fitur';

  @override
  String get openSource => 'Ucapan terima kasih open source';

  @override
  String get feedback => 'Masukan pengguna';

  @override
  String get officialWebsite => 'Situs resmi';

  @override
  String get qqGroup => 'Grup QQ';

  @override
  String get projectRepo => 'Repositori';

  @override
  String get testMembers => 'Anggota penguji';

  @override
  String get aiSupport => 'Dukungan komputasi AI';

  @override
  String get copyAppInfo => 'Salin info aplikasi';

  @override
  String get appInfoCopied => 'Info aplikasi tersalin';

  @override
  String get shareApp => 'Bagikan APRSlocus';

  @override
  String get shareToSystem => 'Bagikan ke sistem';

  @override
  String get shareToSystemDesc => 'WeChat, QQ, SMS, dll.';

  @override
  String get copyShareText => 'Salin teks berbagi';

  @override
  String get openDownload => 'Buka halaman unduhan';

  @override
  String get shareTextCopied =>
      'Teks berbagi tersalin; tempel dan kirim ke teman';

  @override
  String get shareText =>
      'APRSlocus — Pelacakan & Peta APRS untuk radio amatir 📡\nPelacakan stasiun waktu nyata, pesan, dan beacon. Tersedia untuk Android / Windows.\nSitus web: https://aprslocus.theez.top/\nUnduh: https://github.com/dariondong/APRSLocus/releases';

  @override
  String get enterCallsign => 'Masukkan tanda panggil Anda';

  @override
  String get enterValidCall => 'Masukkan tanda panggil yang valid';

  @override
  String get stationSettings2 => 'Pengaturan stasiun';

  @override
  String get beaconSettings => 'Pelaporan beacon';

  @override
  String get displaySettings2 => 'Pengaturan tampilan';

  @override
  String get chatSettings2 => 'Pengaturan obrolan';

  @override
  String get dataSettings2 => 'Pengaturan data';

  @override
  String get advancedSettings2 => 'Pengaturan lanjutan';

  @override
  String get connectionSettings2 => 'Pengaturan koneksi';

  @override
  String get myCallsign => 'Tanda panggil saya';

  @override
  String get beaconEnabled => 'Aktifkan beacon posisi';

  @override
  String get smartBeacon => 'SmartBeacon (berdasarkan kecepatan)';

  @override
  String get packetConsole => 'Konsol paket';

  @override
  String get rawMode => 'Mode mentah';

  @override
  String get parsedMode => 'Mode terurai';

  @override
  String get position => 'Posisi';

  @override
  String get statusType => 'Status';

  @override
  String get objectType => 'Objek';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return 'Terima $rx · Kirim $tx · $ppm/mnt';
  }

  @override
  String get searchPacket => 'Cari tanda panggil, tujuan, atau data mentah…';

  @override
  String get noMatchingPackets => 'Tidak ada paket yang cocok';

  @override
  String get inject => 'Suntik';

  @override
  String get manualInject => 'Suntikkan paket APRS mentah';

  @override
  String get injected => 'Paket tersuntik';

  @override
  String get clearedPackets => 'Paket terhapus';

  @override
  String get clearPackets => 'Hapus paket';

  @override
  String noPositionInfo(Object call) {
    return 'Tidak ada info posisi untuk $call (paket tidak memuat posisi)';
  }

  @override
  String get copiedPacket => 'Paket tersalin';

  @override
  String get mapPickMode => 'Mode pemilih posisi';

  @override
  String get mapPickDesc => 'Ketuk peta untuk menetapkan posisi Anda';

  @override
  String foundStations(Object count, Object q) {
    return 'Ditemukan $count stasiun cocok “$q”';
  }

  @override
  String get tapMapHint => 'Ketuk peta untuk stasiun · cubit untuk zoom';

  @override
  String myLocationPanel(Object call) {
    return 'Lokasi saya · $call';
  }

  @override
  String get speedLabel => 'Kecepatan';

  @override
  String get courseLabel => 'Arah';

  @override
  String get telemetryTitle => 'Kecepatan / Ketinggian';

  @override
  String get range10m => '10 menit';

  @override
  String get range30m => '30 menit';

  @override
  String get range1h => '1 jam';

  @override
  String get range3h => '3 jam';

  @override
  String get rangeAll => 'Semua';

  @override
  String get beaconIntervalLabel => 'Interval';

  @override
  String get beaconsSentLabel => 'Terkirim';

  @override
  String get nextBeaconLabel => 'Berikutnya';

  @override
  String positionBeacon(Object grid) {
    return 'Beacon posisi · Grid $grid';
  }

  @override
  String get manualBeacon => 'Beacon sekarang';

  @override
  String get mapPickNow => 'Pilih di peta';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return 'Posisi ditetapkan · $lat, $lng · Grid $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count online';
  }

  @override
  String movingCount(Object count) {
    return '$count bergerak';
  }

  @override
  String stationCount(Object count) {
    return '$count stasiun';
  }

  @override
  String get locateMe => 'Lokasi';

  @override
  String get layerFilter => 'Lapisan';

  @override
  String get showAll => 'Tampilkan semua';

  @override
  String get otherType => 'Lainnya';

  @override
  String zoomLevel(Object z) {
    return 'Zoom $z';
  }

  @override
  String get datumGcj => 'GCJ-02';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '$d km';
  }

  @override
  String get noStationInView =>
      'Tidak ada stasiun di sini · ketuk untuk tampilkan semua';

  @override
  String get noStationHelp => 'Tidak ada stasiun di sini · ketuk untuk bantuan';

  @override
  String get mapHelpTitle => 'Bantuan peta';

  @override
  String get mapHelpIntro =>
      'Tidak ada stasiun dalam tampilan. Kemungkinan: belum tersambung ke APRS-IS, jangkauan terima kecil, atau tidak ada stasiun aktif di sekitar.';

  @override
  String get mapHelpMove =>
      'Geser / zoom: seret dengan satu jari, cubit atau roda gulir untuk zoom';

  @override
  String get mapHelpStation =>
      'Stasiun: ketuk penanda untuk memilih & memusatkan, ketuk dua kali untuk detail';

  @override
  String get mapHelpLayer =>
      'Lapisan & gaya: tombol kanan atas menyaring jenis stasiun / mengganti peta dasar';

  @override
  String get mapHelpLocate =>
      'Lokasi: ketuk “Lokasi” (kanan bawah) untuk kembali ke posisi Anda';

  @override
  String get mapHelpSearch =>
      'Cari: ketik tanda panggil di kotak pencarian atas untuk melompat ke stasiun itu';

  @override
  String get allChangelog => 'Semua catatan rilis';

  @override
  String get tapToView => 'Ketuk untuk melihat';

  @override
  String get beaconNow => 'Beacon sekarang';

  @override
  String get meLabel => 'Saya';

  @override
  String get mapZoomIn => 'Perbesar';

  @override
  String get mapZoomOut => 'Perkecil';

  @override
  String get mapHome => 'Kembali ke pusat';

  @override
  String get mapLocate => 'Lokasi';

  @override
  String get mapLayers => 'Lapisan';

  @override
  String get featureLiveMap => 'Peta daring';

  @override
  String get featureLiveMapDesc =>
      'Koordinat GCJ-02, zoom dan geser yang lancar';

  @override
  String get featureGps => 'Positioning GPS';

  @override
  String get featureGpsDesc => 'Lokasi native Android, tanpa layanan Google';

  @override
  String get featureBeacon => 'Beaconing';

  @override
  String get featureBeaconDesc =>
      'Kustomisasi isi, frekuensi, dan simbol dengan format standar APRS';

  @override
  String get featureMsg => 'Pesan';

  @override
  String get featureMsgDesc =>
      'Tampilan feed + percakapan dengan teks Unicode dan balasan otomatis';

  @override
  String get featureAutoConnect => 'Sambung otomatis';

  @override
  String get featureAutoConnectDesc =>
      'Otomatis menyambung ke server publik dan tetap online di latar belakang';

  @override
  String get featureLayerFilter => 'Filter lapisan';

  @override
  String get featureLayerFilterDesc =>
      'Filter: bergerak, tetap, digipeater, cuaca, FMO';

  @override
  String get featureFmo => 'Stasiun FMO';

  @override
  String get featureFmoDesc =>
      'Otomatis mengenali data FMO dan menampilkan detail terstruktur';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Kerangka UI lintas platform dari Google';

  @override
  String get osAmap => 'AMAP';

  @override
  String get osAmapDesc => 'Layanan tile peta';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => 'Jaringan data APRS global';

  @override
  String get osHam => 'Radio amatir';

  @override
  String get osHamDesc => 'Kontribusi dari komunitas radio amatir APRS';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => 'Tanda panggil';

  @override
  String get website => 'Situs web';

  @override
  String get sponsorAuthor => 'Penulis BG7LZQ';

  @override
  String get sponsorAuthorItems =>
      'Mengembangkan dan memelihara proyek ini di waktu luang';

  @override
  String get sponsorGroup => 'STUDENT HAMS';

  @override
  String get sponsorGroupItems => 'Terima kasih atas dukungan dana dari grup';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => 'Terima kasih atas sponsor minuman Mixue 🧋';

  @override
  String get sponsorEvery => 'Setiap pendukung';

  @override
  String get sponsorEveryItems =>
      'Setiap dukungan Anda adalah semangat bagi kami';

  @override
  String get donateWechat => 'Donasi WeChat';

  @override
  String get donateWechatDesc =>
      'Tekan lama untuk menyimpan kode QR · ketuk untuk memperbesar';

  @override
  String get donateAlipay => 'Donasi Alipay';

  @override
  String get donateAlipayDesc => 'Hubungi penulis untuk kode QR donasi';

  @override
  String get nonprofitNote =>
      'Proyek ini bersifat non-profit untuk pembelajaran dan komunitas.\nDonasi hanya untuk biaya server dan pengembangan';

  @override
  String get myStation => 'Stasiun saya';

  @override
  String get callSsid => 'Tanda panggil · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc =>
      'SSID adalah akhiran tanda panggil untuk perangkat, mis. -9 pada BG7ABC-9';

  @override
  String get callComment => 'Komentar stasiun';

  @override
  String get callCommentHint => 'Komentar yang dikirim bersama beacon posisi';

  @override
  String get callSymbol => 'Simbol stasiun';

  @override
  String get callSymbolDesc => 'Simbol dikirim bersama beacon posisi';

  @override
  String get autoReply => 'Balasan otomatis';

  @override
  String get sendBeacon => 'Kirim beacon';

  @override
  String get mapTypeDesc =>
      '“Peta 2.0 (vektor)” merender vektor di perangkat sehingga hemat data dan tetap tajam saat zoom; sumber raster memakai tile daring, jadi kualitasnya bergantung jaringan.';

  @override
  String get offlineLoading => 'Memuat…';

  @override
  String get offlineMap => 'Peta offline';

  @override
  String get offlineMapDesc =>
      'Unduh ubin peta lebih dulu agar peta tetap tampil tanpa jaringan';

  @override
  String get offlineMapFooter =>
      'Ubin hanya tersimpan di perangkat ini dan tidak diunggah; tiap sumber punya cache sendiri';

  @override
  String get offlineRegions => 'Area offline';

  @override
  String get offlineRegionsDesc =>
      'Area yang diunduh dapat dilihat di peta secara offline';

  @override
  String get offlineNew => 'Area baru';

  @override
  String get offlineNoRegions => 'Belum ada area offline';

  @override
  String get offlineNoRegionsHint =>
      'Ketuk \"Area baru\" untuk mengunduh tempat yang sering Anda kunjungi';

  @override
  String get offlineCacheUsage => 'Cache ubin';

  @override
  String get offlineCacheUsageDesc =>
      'Otomatis di-cache saat menjelajah; area juga bisa diunduh manual';

  @override
  String get offlineClearCache => 'Hapus semua cache ubin';

  @override
  String get offlineClearCacheConfirm => 'Hapus semua ubin peta yang diunduh?';

  @override
  String get offlineClearCacheConfirmBody =>
      'Ubin yang diunduh akan dihapus; catatan area tetap dan perlu diunduh ulang untuk offline.';

  @override
  String get offlineAreaHint => 'Tampilan saat ini adalah area yang diunduh';

  @override
  String get offlineSource => 'Sumber peta';

  @override
  String get offlineName => 'Nama';

  @override
  String get offlineNameHint => 'mis. Sekitar rumah';

  @override
  String get offlineStartDownload => 'Mulai unduh';

  @override
  String get offlineStatusPending => 'Menunggu';

  @override
  String get offlineStatusRunning => 'Mengunduh';

  @override
  String get offlineStatusPaused => 'Dijeda';

  @override
  String get offlineStatusDone => 'Selesai';

  @override
  String get offlineStatusCanceled => 'Dibatalkan';

  @override
  String get offlineStatusFailed => 'Gagal';

  @override
  String get offlinePause => 'Jeda';

  @override
  String get offlineResume => 'Lanjutkan';

  @override
  String get offlineCancelDownload => 'Batal';

  @override
  String get offlineDeleteKeepTiles => 'Hapus catatan saja (ubin tetap ada)';

  @override
  String get offlineDeleteWithTiles => 'Hapus catatan dan ubinnya';

  @override
  String get offlineDownloadBusy =>
      'Ada unduhan lain yang berjalan — tunggu atau batalkan dulu';

  @override
  String get offlineCacheSwitch => 'Cache ubin peta';

  @override
  String get offlineCacheSwitchDesc =>
      'Simpan ubin saat menjelajah agar bisa dilihat offline nanti';

  @override
  String get offlineOnlySwitch => 'Hanya ubin offline';

  @override
  String get offlineOnlySwitchDesc =>
      'Tidak memuat ubin dari jaringan — hanya yang terunduh/ter-cache (hemat kuota)';

  @override
  String get offlineCacheDisabled =>
      'Cache ubin tidak tersedia di platform ini';

  @override
  String get offlineSwitchFirst => 'Aktifkan \"Cache ubin peta\" dulu';

  @override
  String get offlineOnlyWarn =>
      '\"Hanya ubin offline\" aktif — sebagian peta mungkin tidak tampil';

  @override
  String offlineTilesDownloaded(String n) {
    return '$n ubin terunduh';
  }

  @override
  String offlineZoomLevels(String min, String max) {
    return 'zoom $min–$max';
  }

  @override
  String offlineEstimate(String tiles, String size) {
    return 'sekitar $tiles ubin · sekitar $size';
  }

  @override
  String offlineTooManyTiles(String tiles) {
    return 'Area terlalu besar (sekitar $tiles ubin) — perkecil area atau turunkan zoom maksimum';
  }

  @override
  String offlineDeleteRegionConfirm(String name) {
    return 'Hapus area offline \"$name\"?';
  }

  @override
  String offlineDeleteTileCount(String n) {
    return 'Sekitar $n ubin akan dihapus';
  }

  @override
  String offlineDeletingTiles(String done, String total) {
    return 'Menghapus $done/$total';
  }

  @override
  String offlineFailedCount(String n) {
    return '$n gagal';
  }

  @override
  String offlineTileProgress(String done, String total) {
    return '$done/$total ubin';
  }

  @override
  String get msgHistory => 'Riwayat pesan';

  @override
  String get statistics => 'Statistik';

  @override
  String get clearData => 'Hapus data';

  @override
  String get favorites => 'Favorit / Manual';

  @override
  String get favoriteStations => 'Stasiun favorit';

  @override
  String get manualStations => 'Stasiun manual';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get onlyWgs84 => 'Hanya WGS-84';

  @override
  String get contactList => 'Kontak';

  @override
  String get contactDesc => 'Aturan filter pesan/kontak';

  @override
  String get dataClearDesc =>
      'Hapus pesan, paket, stasiun, dan data lokal lainnya';

  @override
  String get advancedDesc => 'Lab & alat pengembang';

  @override
  String get labDesc =>
      'Fitur lab masih diuji dan dapat memengaruhi pengalaman. Orientasi potret dikunci secara bawaan; aktifkan ini untuk mengizinkan lanskap.';

  @override
  String get systemLog => 'Log sistem';

  @override
  String get devDesc => 'Alat debug pengembang';

  @override
  String get simData => 'Aktifkan data demo (contoh stasiun/paket)';

  @override
  String get rxTx => 'RX / TX';

  @override
  String get stationCount2 => 'Jumlah stasiun';

  @override
  String get appInfo => 'Info aplikasi';

  @override
  String get clearMessages => 'Hapus semua riwayat obrolan';

  @override
  String get clearPackets2 => 'Hapus paket';

  @override
  String get clearStations => 'Hapus daftar stasiun';

  @override
  String get clearCache => 'Hapus cache';

  @override
  String get resetAll => 'Reset semua pengaturan';

  @override
  String get resetAllDesc => 'Kembalikan ke pengaturan pabrik';

  @override
  String get dataPersistence => 'Penyimpanan stasiun';

  @override
  String get autoSaveStations => 'Simpan data stasiun otomatis';

  @override
  String get gridFormat => 'Format grid';

  @override
  String get coordsFormat => 'Format koordinat';

  @override
  String get appVersion => 'Versi';

  @override
  String get appVersionDesc => 'Versi aplikasi saat ini';

  @override
  String get stationDetail => 'Detail stasiun';

  @override
  String get backToTop => 'Kembali ke atas';

  @override
  String get installApk => 'Pasang APRSlocus';

  @override
  String get install => 'Pasang';

  @override
  String get cancelInstall => 'Batal';

  @override
  String get openFolder => 'Buka folder';

  @override
  String get browse => 'Telusuri';

  @override
  String get downloadUpdate => 'Unduh pembaruan';

  @override
  String get downloadNow => 'Unduh sekarang';

  @override
  String get downloading => 'Mengunduh';

  @override
  String downloadProgress(Object p) {
    return 'Mengunduh $p%';
  }

  @override
  String get downloadComplete => 'Unduhan selesai';

  @override
  String get downloadFailed => 'Unduhan gagal';

  @override
  String get installNow => 'Pasang sekarang';

  @override
  String get installComplete => 'Pemasangan selesai';

  @override
  String get openInstallDir => 'Buka folder pemasangan';

  @override
  String get deletePackage => 'Hapus paket';

  @override
  String deletePackageConfirm(Object file) {
    return 'Hapus paket $file?';
  }

  @override
  String get deleteAllPackages => 'Hapus semua paket';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return 'Hapus semua paket ($count)';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return 'Hapus $count paket terunduh ($size)? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get historyVersions => 'Riwayat versi';

  @override
  String get current => 'Saat ini';

  @override
  String get newVersion => 'Versi baru';

  @override
  String get latestVersion => 'Anda sudah menggunakan versi terbaru';

  @override
  String get currentVersion => 'Versi APRSlocus saat ini';

  @override
  String get checking => 'Memeriksa pembaruan…';

  @override
  String get checkingGitCode => 'Memeriksa repositori GitCode';

  @override
  String get updateFailed => 'Pemeriksaan pembaruan gagal';

  @override
  String get noUpdateFound => 'Anda sudah menggunakan versi terbaru';

  @override
  String get newVersionFound => 'Versi baru tersedia';

  @override
  String get downloadAgain => 'Unduh ulang paket';

  @override
  String get openDownloads => 'Buka folder unduhan';

  @override
  String get releaseNotes => 'Catatan rilis';

  @override
  String currentVsRepo(Object local, Object remote) {
    return 'Terpasang v$local · Terbaru v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return 'Ukuran paket $os: $size';
  }

  @override
  String get alreadyDownloaded => 'Paket sudah diunduh';

  @override
  String get downloadReady => 'Unduh paket pemasangan';

  @override
  String get appInstallDir => 'Folder pemasangan';

  @override
  String get runInstaller => 'Jalankan installer';

  @override
  String get downloadUpdateTip => 'Unduh pembaruan lalu buka otomatis';

  @override
  String get openDownloadFolder => 'Buka folder unduhan';

  @override
  String groupBubble(String name) {
    return 'Grup · $name';
  }

  @override
  String get groupInviteTitle => 'Undangan obrolan grup';

  @override
  String groupInviteFrom(String from) {
    return '$from mengundang Anda ke obrolan grup';
  }

  @override
  String groupNameValue(String name) {
    return 'Nama grup: $name';
  }

  @override
  String groupCallsignValue(String call) {
    return 'Tanda panggil grup: $call';
  }

  @override
  String groupInviteAccepted(String name) {
    return 'Bergabung ke $name';
  }

  @override
  String get accept => 'Terima';

  @override
  String groupInviteRejected(String name) {
    return 'Menolak undangan ke $name';
  }

  @override
  String get reject => 'Tolak';

  @override
  String get appTagline => 'Pelacakan APRS';

  @override
  String gridValue(String grid) {
    return 'Grid $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/mnt';
  }

  @override
  String get demo => 'Demo';

  @override
  String nextBeaconIn(String time) {
    return 'Beacon berikutnya $time';
  }

  @override
  String beaconCount(int count) {
    return 'Beacon $count';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return 'Beacon posisi terkirim · Grid $grid · Terkirim ke APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return 'Beacon posisi terkirim · Grid $grid · Demo';
  }

  @override
  String get getLocation => 'Dapatkan lokasi';

  @override
  String get disconnect => 'Putuskan';

  @override
  String get connectAprsIs => 'Sambungkan APRS-IS';

  @override
  String get packetsReceived => 'RX';

  @override
  String get passcodeUnverified => 'Passcode belum diverifikasi';

  @override
  String get passcodeWarning =>
      'Passcode login mungkin salah; pesan mungkin tidak berfungsi';

  @override
  String get goSettings => 'Pengaturan';

  @override
  String get connectingServer => 'Menghubungkan ke server…';

  @override
  String get notConnectedAprsServer => 'Belum tersambung ke APRS-IS';

  @override
  String connectingToServer(String server, int port) {
    return 'Menghubungkan ke $server:$port…';
  }

  @override
  String get connectNearbyDesc =>
      'Setelah tersambung, Anda menerima posisi dan pesan stasiun di sekitar';

  @override
  String get connectAction => 'Sambungkan';

  @override
  String get backgroundRunTip =>
      'Tips latar belakang: agar pelaporan posisi tetap berjalan, izinkan APRSlocus berjalan di latar belakang, nonaktifkan optimasi baterai, dan izinkan autostart.';

  @override
  String get connectedAprsIs => 'Tersambung ke APRS-IS';

  @override
  String get qqGroupDesc => 'APRSlocus · Masukan dan diskusi';

  @override
  String get reselectPoint => 'Pilih ulang';

  @override
  String get disableClustering => 'Nonaktifkan pengelompokan';

  @override
  String get enableClustering => 'Aktifkan pengelompokan';

  @override
  String get heatmap => 'Peta panas stasiun';

  @override
  String get heatmapHint =>
      'Tampilkan peta panas kepadatan stasiun saat zoom diperkecil';

  @override
  String get groupTracking => 'Pelacakan grup';

  @override
  String get groupTrackingHint =>
      'Kelompokkan tanda panggil yang Anda pantau dan lacak di peta besar (konvoi / bersama teman). Mendukung lanskap.';

  @override
  String get newTrackGroup => 'Grup pelacakan baru';

  @override
  String get trackGroupNameHint => 'Nama, mis. Bersepeda Akhir Pekan';

  @override
  String get editTrackGroup => 'Edit grup pelacakan';

  @override
  String get deleteTrackGroup => 'Hapus grup pelacakan';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return 'Hapus grup pelacakan “$name”?';
  }

  @override
  String get pickTrackMembers =>
      'Pilih anggota (centang tanda panggil yang dilacak)';

  @override
  String get saveAndTrack => 'Simpan & lacak';

  @override
  String get trackGroupsEmptyHint =>
      'Belum ada grup pelacakan. Ketuk “Grup pelacakan baru” untuk membuatnya.';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty =>
      'Anggota belum memiliki data posisi (belum diterima atau belum beacon). Ketuk di bawah untuk mengedit anggota.';

  @override
  String get trackActive => 'Online';

  @override
  String get trackWaitingPos => 'Menunggu posisi…';

  @override
  String get offlineShort => 'Offline';

  @override
  String get stoppedShort => 'Berhenti';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total anggota · $online online · $fixed terposisi';
  }

  @override
  String get groupChatShort => 'Obrolan';

  @override
  String groupChatTitle(Object name) {
    return 'Grup · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return 'Obrolan dengan $call';
  }

  @override
  String get chatToGroupHint => 'Kirim pesan ke grup…';

  @override
  String chatToHint(Object call) {
    return 'Pesan ke $call…';
  }

  @override
  String get noMessagesHint => 'Belum ada pesan — sapa dulu!';

  @override
  String trackModeFollow(Object call) {
    return 'Mengikuti $call';
  }

  @override
  String get trackModeMe => 'Mengikuti saya';

  @override
  String get trackModeFitAll => 'Tetap muat semua';

  @override
  String get fitAll => 'Muat semua';

  @override
  String get noStationsYet =>
      'Belum ada data stasiun. Sambungkan ke APRS-IS untuk memilih anggota.';

  @override
  String get noPackets => 'Belum ada paket';

  @override
  String secondsAgo(int count) {
    return '$count dtk lalu';
  }

  @override
  String minutesAgo(int count) {
    return '$count mnt lalu';
  }

  @override
  String hoursAgo(int count) {
    return '$count jam lalu';
  }

  @override
  String daysAgo(int count) {
    return '$count hari lalu';
  }

  @override
  String copiedCoordsValue(String coords) {
    return 'Koordinat tersalin: $coords';
  }

  @override
  String copiedGridValue(String grid) {
    return 'Grid tersalin: $grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return '$distance km dari saya · Azimut $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return 'Cuaca · $data';
  }

  @override
  String get symbolLabel => 'Simbol';

  @override
  String get digipeaterTapHint =>
      'Ketuk digipeater untuk membuka detail stasiunnya';

  @override
  String get copiedFmoInfo => 'Info FMO tersalin';

  @override
  String get copiedAprslocusInfo => 'Info APRSlocus tersalin';

  @override
  String trackPoints(int count) {
    return 'Jejak ($count titik)';
  }

  @override
  String sendMessageTo(String call) {
    return 'Pesan ke $call…';
  }

  @override
  String get navigationUnavailable =>
      'Tidak ada aplikasi peta terpasang dan tidak ada aplikasi peta lain yang bisa dibuka';

  @override
  String stationNoData(String call) {
    return 'Belum ada data diterima dari $call';
  }

  @override
  String get software => 'Perangkat lunak';

  @override
  String get close => 'Tutup';

  @override
  String get nameLabel => 'Nama';

  @override
  String get viewSponsorDetails => 'Lihat detail penulis dan sponsor →';

  @override
  String get thanks => 'Terima kasih';

  @override
  String get qqSoftwareName => 'APRSlocus';

  @override
  String get usageNotice =>
      'Hanya untuk pembelajaran dan komunikasi radio amatir.\nPatuhi peraturan radio setempat';

  @override
  String get licenseNotice => 'GNU GPL v3 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\nPenulis: BG7LZQ (Darion)\nSitus web: Theez.top';
  }

  @override
  String get eggBg7lzq => 'Eh, kamu ngapain~';

  @override
  String get eggBg7pgw => 'Serius?';

  @override
  String get eggBg7lmw => 'Diam saja...';

  @override
  String get eggBg7osl => 'Nekat sekali';

  @override
  String get manualCallsignHint => 'Masukkan tanda panggil secara manual';

  @override
  String get noPacketReceived => 'Belum ada paket diterima';

  @override
  String get feedMode => 'Feed';

  @override
  String get conversationMode => 'Obrolan';

  @override
  String get messageFeed => 'Feed pesan';

  @override
  String messageTotal(int count) {
    return '$count pesan';
  }

  @override
  String get noMessages => 'Belum ada pesan';

  @override
  String get copiedClipboard => 'Tersalin ke papan klip';

  @override
  String get groupShortLabel => 'Grup';

  @override
  String get conversations => 'Obrolan';

  @override
  String get noConversations => 'Belum ada percakapan';

  @override
  String get groupNotFound => 'Grup tidak ditemukan';

  @override
  String get invite => 'Undang';

  @override
  String get manage => 'Kelola';

  @override
  String get noGroupMessages => 'Belum ada pesan grup';

  @override
  String get selectConversation => 'Pilih percakapan untuk mulai mengobrol';

  @override
  String get newConversation => 'Percakapan baru';

  @override
  String get newConversationDesc =>
      'Masukkan tanda panggil untuk memulai percakapan';

  @override
  String get callsignExample => 'Tanda panggil, mis. BG7ABC';

  @override
  String get start => 'Mulai';

  @override
  String get broadcastMessage => 'Pesan siaran';

  @override
  String get noStations => 'Tidak ada stasiun';

  @override
  String get broadcastHint =>
      'Setiap pesan dikirim terpisah ke setiap penerima';

  @override
  String broadcastSent(int count) {
    return 'Terkirim ke $count penerima';
  }

  @override
  String get searchCallsign => 'Cari tanda panggil…';

  @override
  String get broadcastContentHint => 'Masukkan pesan untuk disiarkan…';

  @override
  String get groupNameHint => 'Masukkan nama grup';

  @override
  String get create => 'Buat';

  @override
  String groupCallsignLine(String call) {
    return 'Tanda panggil grup: $call';
  }

  @override
  String get noMembers => 'Belum ada anggota';

  @override
  String get inviteMembersHint =>
      'Ketuk “Undang anggota” di bawah untuk menambahkan';

  @override
  String get remove => 'Hapus';

  @override
  String get inviteMembers => 'Undang anggota';

  @override
  String get deleteGroup => 'Hapus grup';

  @override
  String deleteGroupConfirm(String name) {
    return 'Hapus “$name”? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get deleteConversation => 'Hapus obrolan';

  @override
  String deleteConversationConfirm(Object call) {
    return 'Hapus riwayat obrolan dengan $call? Obrolan juga akan dihapus dari daftar. Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return 'Hapus riwayat obrolan “$name”? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members anggota · $online online';
  }

  @override
  String get leaveGroup => 'Keluar dari grup';

  @override
  String leaveGroupConfirm(String name) {
    return 'Keluar dari “$name”? Anda tidak akan menerima pesan dari grup ini.';
  }

  @override
  String leftGroup(String name) {
    return 'Keluar dari $name';
  }

  @override
  String get leave => 'Keluar';

  @override
  String inviteMembersTo(String name) {
    return 'Undang anggota ke $name';
  }

  @override
  String get manualCallsign => 'Masukkan tanda panggil manual';

  @override
  String inviteSent(String call) {
    return 'Undangan terkirim ke $call';
  }

  @override
  String get noMoreOnlineStations => 'Tidak ada lagi stasiun online';

  @override
  String get invited => 'Diundang';

  @override
  String get tapToInvite => 'Ketuk untuk mengundang';

  @override
  String get done => 'Selesai';

  @override
  String get addContact => 'Tambah kontak';

  @override
  String get addContactDesc =>
      'Masukkan tanda panggil untuk menambahkannya ke kontak';

  @override
  String contactAdded(String call) {
    return 'Kontak $call ditambahkan';
  }

  @override
  String get add => 'Tambah';

  @override
  String get stationary => 'Diam';

  @override
  String get unknown => 'Tidak diketahui';

  @override
  String get none => 'Tidak ada';

  @override
  String get manual => 'Manual';

  @override
  String get management => 'Kelola';

  @override
  String get debugLabel => 'Debug';

  @override
  String get information => 'Info';

  @override
  String get warning => 'Peringatan';

  @override
  String get errorLabel => 'Kesalahan';

  @override
  String countTimes(int count) {
    return '$count kali';
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
      'car': 'Mobil',
      'police': 'Polisi',
      'person': 'Orang',
      'digitalRepeater': 'Digipeater digital',
      'telephone': 'Telepon',
      'dxCluster': 'Kluster DX',
      'hfGateway': 'Gateway HF',
      'smallAircraft': 'Pesawat kecil',
      'mobileSatellite': 'Satelit bergerak',
      'disabled': 'Difabel',
      'snowmobile': 'Mobil salju',
      'redCross': 'Palang merah',
      'scouts': 'Pramuka',
      'house': 'Rumah',
      'redX': 'Tanda silang merah',
      'redDot': 'Titik merah',
      'fire': 'Kebakaran',
      'campground': 'Berkemah',
      'motorcycle': 'Sepeda motor',
      'train': 'Kereta',
      'fileServer': 'Server berkas',
      'hurricane': 'Badai',
      'dfTriangle': 'Segitiga DF',
      'postOffice': 'Kantor pos',
      'largeAircraft': 'Pesawat besar',
      'weatherStation': 'Stasiun cuaca',
      'satelliteDish': 'Antena satelit',
      'ambulance': 'Ambulans',
      'bicycle': 'Sepeda',
      'commandPost': 'Pusat komando',
      'fireStation': 'Pos pemadam',
      'horse': 'Berkuda',
      'fireTruck': 'Mobil pemadam',
      'glider': 'Pesawat layang',
      'hospital': 'Rumah sakit',
      'fmoStation': 'Stasiun FMO',
      'jeep': 'Jeep',
      'truck': 'Truk',
      'laptop': 'Laptop',
      'micERepeater': 'Digipeater Mic-E',
      'node': 'Node',
      'emergencyOps': 'Operasi darurat',
      'dog': 'Anjing',
      'gridSquare': 'Grid',
      'repeaterTower': 'Menara repeater',
      'boat': 'Kapal',
      'truckStop': 'Tempat istirahat truk',
      'semiTrailer': 'Truk gandeng',
      'van': 'Van',
      'waterStation': 'Stasiun air',
      'yagi': 'Antena Yagi',
      'shelter': 'Tempat berlindung',
      'rv': 'RV',
      'weatherSymbol': 'Stasiun cuaca',
      'balloon': 'Balon',
      'bus': 'Bus',
      'shuttle': 'Pesawat ulang-alik',
      'policeCar': 'Mobil polisi',
      'sailboat': 'Kapal layar',
      'school': 'Sekolah',
      'lodging': 'Penginapan',
      'hotel': 'Hotel',
      'other': 'Tidak diketahui',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': 'Kendaraan / Lalu lintas',
      'facilities': 'Bangunan / Fasilitas',
      'weatherNature': 'Cuaca / Alam',
      'emergencyRescue': 'Tanggap darurat',
      'airWater': 'Udara / Perairan',
      'communications': 'Komunikasi / Lainnya',
      'other': 'Lainnya',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': 'Tiongkok',
      'KR': 'Korea Selatan',
      'JP': 'Jepang',
      'US': 'Amerika Serikat',
      'CA': 'Kanada',
      'GB': 'Britania Raya',
      'DE': 'Jerman',
      'FR': 'Prancis',
      'IT': 'Italia',
      'ES': 'Spanyol',
      'RU': 'Rusia',
      'AU': 'Australia',
      'NZ': 'Selandia Baru',
      'BR': 'Brasil',
      'AR': 'Argentina',
      'MX': 'Meksiko',
      'ZA': 'Afrika Selatan',
      'IN': 'India',
      'TH': 'Thailand',
      'SG': 'Singapura',
      'MY': 'Malaysia',
      'ID': 'Indonesia',
      'PH': 'Filipina',
      'TW': 'Taiwan',
      'HK': 'Hong Kong',
      'MO': 'Makau',
      'other': 'Tidak diketahui',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => 'Belum ada posisi';

  @override
  String get simulatedLocation => 'Lokasi simulasi';

  @override
  String get savedLocation => 'Lokasi tersimpan';

  @override
  String get locationFailed => 'Gagal menentukan lokasi';

  @override
  String get locationStopped => 'Lokasi dihentikan';

  @override
  String get locationFixed => 'Posisi didapat';

  @override
  String get locationPermission => 'Izinkan akses lokasi…';

  @override
  String get gpsLocating => 'Mendapatkan lokasi GPS…';

  @override
  String get webLocationUnsupported =>
      'Lokasi otomatis tidak tersedia di web; masukkan koordinat manual';

  @override
  String locationStreamError(String error) {
    return 'Galat aliran lokasi: $error';
  }

  @override
  String locationInitError(String error) {
    return 'Inisialisasi lokasi gagal: $error';
  }

  @override
  String get beaconDisabled => 'Nonaktif';

  @override
  String get waitingForLocation => 'Menunggu lokasi';

  @override
  String get imminent => 'Segera';

  @override
  String get connTapToConnect =>
      'Belum tersambung · masuk APRS-IS dengan tombol sambungkan';

  @override
  String get connManuallyDisconnected => 'Belum tersambung · diputus manual';

  @override
  String connAutoReconnect(int seconds) {
    return 'Koneksi terputus · menyambung ulang dalam $seconds dtk…';
  }

  @override
  String connConnectingTarget(String target) {
    return 'Menghubungkan ke $target…';
  }

  @override
  String connOnline(String call) {
    return 'Tersambung · $call online';
  }

  @override
  String connRetry(int seconds) {
    return 'Koneksi gagal · mencoba lagi dalam $seconds dtk…';
  }

  @override
  String connPositionSent(String call) {
    return 'Tersambung · beacon posisi terkirim ($call)';
  }

  @override
  String get connDemoBeacon =>
      'Belum tersambung · beacon posisi tercatat (demo)';

  @override
  String get connPasscodeInvalid =>
      'Tersambung · belum diverifikasi (Passcode mungkin salah)';

  @override
  String get mapTypeAmap => 'AMAP';

  @override
  String get mapTypeAmapSatellite => 'AMAP Satelit';

  @override
  String get mapTypeVector => 'Peta vektor';

  @override
  String get amapGroup => 'Domestik';

  @override
  String get domesticMaps => 'Peta Tiongkok';

  @override
  String get internationalMaps => 'Peta global';

  @override
  String get metricUnits => 'Metrik (km/j, m)';

  @override
  String get coordDisplay => 'Tampilan koordinat';

  @override
  String mapDefaultCoord(int level) {
    return 'Beijing · Zoom $level';
  }

  @override
  String secondsValue(int count) {
    return '$count dtk';
  }

  @override
  String get stationSettingsDetail => 'Tanda panggil, SSID, simbol & komentar';

  @override
  String get stationIdentity => 'Identitas stasiun';

  @override
  String get aprsCallsignHint => 'Tanda panggil APRS, mis. BV2AAA';

  @override
  String get displayInfo => 'Info stasiun';

  @override
  String get ssidSuffix => 'Akhiran SSID';

  @override
  String get chooseSsidSuffix => 'Pilih akhiran SSID';

  @override
  String get mySymbol => 'Simbol saya';

  @override
  String get moreSymbols => 'Simbol lainnya';

  @override
  String get allAprsSymbols => 'Semua simbol APRS';

  @override
  String get beaconSettingsDetail => 'Sumber GPS, beacon & posisi manual';

  @override
  String get locationSource => 'Sumber lokasi';

  @override
  String get useDeviceLocation => 'Gunakan lokasi perangkat';

  @override
  String get manualCoordinates => 'Masukkan koordinat manual';

  @override
  String get locationMode => 'Mode lokasi';

  @override
  String get settingsLocModeSubtitle => 'Pilih metode lokasi';

  @override
  String get locModeGps => 'Hanya GPS';

  @override
  String get locModeGpsDesc => 'Hanya satelit, hemat baterai';

  @override
  String get locModeGpsNetwork => 'GPS + Jaringan';

  @override
  String get locModeGpsNetworkDesc => 'Berbantuan jaringan, lebih cepat';

  @override
  String get beaconingSection => 'Beaconing';

  @override
  String get beaconIntervalTip => 'Interval beacon posisi, minimal 5 detik';

  @override
  String get beaconContent => 'Isi beacon';

  @override
  String get beaconContentDesc => 'Dikirim bersama setiap beacon posisi';

  @override
  String get phoneBattery => 'Baterai ponsel';

  @override
  String get locationStatus => 'Status lokasi';

  @override
  String get relocate => 'Cari ulang';

  @override
  String get startGps => 'Mulai GPS';

  @override
  String get trackingBeaconing =>
      'Lokasi aktif dan beacon posisi terus dikirim';

  @override
  String get manualLocation => 'Posisi manual';

  @override
  String get latitudeHint => 'Lintang 39.9042';

  @override
  String get longitudeHint => 'Bujur 116.4074';

  @override
  String get invalidLatLng => 'Masukkan lintang dan bujur yang valid';

  @override
  String myLocationSetGrid(String grid) {
    return 'Lokasi ditetapkan · Grid $grid';
  }

  @override
  String get applyCoordinates => 'Terapkan koordinat';

  @override
  String get pickOnMap => 'Pilih di peta';

  @override
  String get manualLocationHelp =>
      'Jika lokasi otomatis tidak tersedia, masukkan koordinat atau pilih titik di peta untuk beaconing dan perhitungan jarak.';

  @override
  String get passcodeTip =>
      'Passcode login APRS-IS; buat online. Isi -1 untuk login belum diverifikasi';

  @override
  String get websocketOptional => 'URL WebSocket (opsional)';

  @override
  String get configChanged => 'Konfigurasi diubah';

  @override
  String get reconnectToApply => 'Sambung ulang untuk menerapkan';

  @override
  String get reconnected => 'Tersambung ulang';

  @override
  String get connectFailedCheckConfig => 'Koneksi gagal; periksa konfigurasi';

  @override
  String get rangeFilterDesc =>
      'Terima hanya paket stasiun dalam jangkauan yang ditentukan';

  @override
  String get filterCenterFollows => 'Ikuti lokasi saya untuk pusat filter';

  @override
  String get radiusTip =>
      'Radius terima (km); ketuk “Simpan & terapkan filter” untuk menerapkan';

  @override
  String get maxStationsTip =>
      'Jumlah maksimum stasiun di memori (bawaan tanpa batas; bisa dinaikkan)';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · Radius $radius km';
  }

  @override
  String get receiveFilterDesc2 =>
      'Selain filter jangkauan, terima stasiun berdasarkan negara/wilayah atau tanda panggil persis';

  @override
  String get receiveCountryDesc =>
      'Terima semua stasiun dari suatu negara/wilayah berdasarkan prefiks tanda panggil';

  @override
  String get noCountriesSelected => 'Belum ada negara/wilayah dipilih';

  @override
  String get receiveOthersDesc =>
      'Terima stasiun dengan tanda panggil khusus yang tidak cocok dengan negara terpilih';

  @override
  String get addCountry => 'Tambah negara/wilayah';

  @override
  String get chatSettingsDetail => 'Pesan, kontak & data obrolan';

  @override
  String get messageCountLabel => 'Pesan';

  @override
  String get manageContacts => 'Kelola kontak';

  @override
  String deleteAllChatsConfirm(int count) {
    return 'Hapus semua $count riwayat obrolan? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get chatCleared => 'Riwayat obrolan dihapus';

  @override
  String get noContacts => 'Belum ada kontak';

  @override
  String get addOrFavoriteContact =>
      'Ketuk “Tambah” di atas atau favoritkan stasiun di peta';

  @override
  String movingWithSpeed(String speed) {
    return 'Bergerak · $speed';
  }

  @override
  String get callsignMin3 => 'Tanda panggil minimal 3 karakter';

  @override
  String get deleteContact => 'Hapus kontak';

  @override
  String deleteContactConfirm(String call) {
    return 'Hapus kontak $call?';
  }

  @override
  String contactDeleted(String call) {
    return '$call dihapus';
  }

  @override
  String get dataMaintenance => 'Pemeliharaan data';

  @override
  String get clearAllData => 'Hapus semua data';

  @override
  String get clearAllDataIntro =>
      'Ini akan menghapus semua data lokal berikut:';

  @override
  String get chatHistory => 'Riwayat obrolan';

  @override
  String get logs => 'Log';

  @override
  String get irreversibleKeepSettings =>
      'Tindakan ini tidak dapat dibatalkan. Pengaturan koneksi dan tanda panggil tetap disimpan.';

  @override
  String get confirmClearAllData => 'Hapus semua data';

  @override
  String get clearAllDataConfirm =>
      'Hapus semua data lokal? Tindakan ini tidak dapat dibatalkan.';

  @override
  String get allDataCleared => 'Semua data lokal dihapus';

  @override
  String get confirmClear => 'Hapus';

  @override
  String get allowLandscape => 'Izinkan orientasi lanskap';

  @override
  String get packetParseTest => 'Tes parser paket';

  @override
  String get packetParseHint =>
      'Tempel paket APRS mentah, mis.:\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Stasiun uji';

  @override
  String get parseAndApply => 'Parsing & terapkan';

  @override
  String get oobePasscodeMissing => 'Passcode belum diisi';

  @override
  String get oobePasscodeMissingDesc =>
      'Passcode adalah kode verifikasi login APRS-IS untuk tanda panggil Anda.\n\nNilai bawaan -1 (belum diverifikasi) dapat tersambung, tetapi pesan dan obrolan grup tidak akan berfungsi normal.\n\nCari Passcode yang benar untuk tanda panggil Anda di https://aprs.cool/AprsPG.';

  @override
  String get continueAnyway => 'Lanjutkan saja';

  @override
  String get fillPasscode => 'Isi Passcode';

  @override
  String get oobeMapFeatureDesc =>
      'Tile peta daring dengan stasiun APRS dan jejak di sekitar';

  @override
  String get oobeGpsFeatureDesc =>
      'Dapatkan lokasi Anda dan kirim beacon posisi ke APRS-IS';

  @override
  String get oobeMsgFeatureDesc =>
      'Bertukar pesan dengan stasiun, mendukung balasan otomatis';

  @override
  String get oobeIsFeatureDesc =>
      'Sambung ke server publik dan terima data stasiun APRS sedunia';

  @override
  String get oobeBackgroundTip =>
      'Tips: izinkan APRSlocus berjalan di latar belakang, nonaktifkan optimasi baterai, dan izinkan autostart agar beaconing tetap aktif.';

  @override
  String get oobeNextSteps =>
      'Selesaikan penyiapan dasar dalam beberapa langkah berikutnya. Anda dapat mengubahnya kapan saja di Pengaturan.';

  @override
  String get ssidDescShort =>
      'SSID adalah akhiran angka pada tanda panggil, mis. -9 pada BG7ABC-9';

  @override
  String get ssidOptional => 'Akhiran SSID (opsional)';

  @override
  String get noSsid => 'Tanpa akhiran (tanda panggil dasar)';

  @override
  String fullCallsign(String call) {
    return 'Tanda panggil lengkap: $call';
  }

  @override
  String get passcodeImportant => 'Passcode itu penting';

  @override
  String get passcodeImportantDesc =>
      'Passcode yang benar diperlukan untuk menerima pesan grup dan mengirim konfirmasi. -1 dapat tersambung, tetapi pesan tidak akan berfungsi normal.';

  @override
  String get lookupPasscode => 'Cari Passcode Anda →';

  @override
  String get passcodeLookupHint => 'Masukkan tanda panggil Anda, mis. BV2AAA';

  @override
  String sendToGroupHint(String group) {
    return 'Kirim ke $group…';
  }

  @override
  String sendToCallHint(String call) {
    return 'Kirim ke $call…';
  }

  @override
  String get selectMessageReply => 'Pilih pesan untuk membalas…';

  @override
  String get broadcastShort => 'Siaran';

  @override
  String memberCount(int count) {
    return '$count anggota';
  }

  @override
  String memberCountTap(int count) {
    return '$count anggota · ketuk untuk melihat';
  }

  @override
  String get stepRecipients => 'Penerima';

  @override
  String get stepContent => 'Pesan';

  @override
  String get selectAllOnline => 'Pilih semua yang online';

  @override
  String get clearSelection => 'Kosongkan pilihan';

  @override
  String get onlineOnly => 'Hanya online';

  @override
  String get noRecipients => 'Belum ada penerima dipilih';

  @override
  String selectedRecipients(int count) {
    return '$count dipilih';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return 'Mengirim ke $count: $calls';
  }

  @override
  String get stepName => 'Nama';

  @override
  String get stepMembers => 'Anggota';

  @override
  String get groupChatExplain =>
      'Obrolan grup menyiarkan ke tanda panggil grup sehingga semua anggota menerimanya. Tanda panggil grup dibuat otomatis dan undangan dikirim ke anggota yang Anda pilih.';

  @override
  String get noMembersSelected => 'Belum ada anggota dipilih';

  @override
  String get memberBlocked => 'Diblokir';

  @override
  String get memberJoined => 'Bergabung';

  @override
  String get memberPending => 'Menunggu';

  @override
  String get memberDeclined => 'Ditolak';

  @override
  String get memberLeft => 'Keluar';

  @override
  String get memberTimeout => 'Waktu habis';

  @override
  String get unblock => 'Buka blokir';

  @override
  String get block => 'Blokir';

  @override
  String get groupOwner => 'Pemilik';

  @override
  String systemMemberJoined(String call) {
    return '$call bergabung ke grup';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call keluar dari grup';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call menolak undangan';
  }

  @override
  String get copyAllLogs => 'Salin semua log';

  @override
  String copiedLogs(int count) {
    return '$count entri log tersalin';
  }

  @override
  String get clearLogs => 'Hapus log';

  @override
  String get noLogs => 'Belum ada log';

  @override
  String get supportProject =>
      'Dukungan Anda membuat proyek ini melangkah lebih jauh';

  @override
  String get continuousIteration => 'Perbaikan berkelanjutan';

  @override
  String get continuousIterationDesc =>
      'Terus meningkatkan fitur dan pengalaman APRSlocus';

  @override
  String get sponsorSupport => 'Dukungan sponsor';

  @override
  String get sponsorMethods => 'Cara mendukung';

  @override
  String qrCodeTitle(String title) {
    return 'Kode QR $title';
  }

  @override
  String get qrLoadFailed => 'Gambar kode QR gagal dimuat';

  @override
  String get qrSaveWechat =>
      'Tekan lama untuk menyimpan · pindai dengan WeChat untuk mendukung';

  @override
  String get tapAnywhereClose => 'Ketuk di mana saja untuk menutup';

  @override
  String vectorMapLoadFailed(String error) {
    return 'Peta vektor gagal dimuat\n$error';
  }

  @override
  String get loadingVectorMap => 'Memuat peta vektor…';

  @override
  String get updateChannel => 'Saluran pembaruan';

  @override
  String serverReturned(int code) {
    return 'Server mengembalikan $code';
  }

  @override
  String get invalidResponseData => 'Format respons tidak valid';

  @override
  String get noVersionsFound => 'Tidak ada rilis ditemukan';

  @override
  String get noWindowsInstaller =>
      'Tidak ada installer Windows untuk rilis ini';

  @override
  String get noApkInstaller => 'Tidak ada APK untuk rilis ini';

  @override
  String get connectingEllipsis => 'Menghubungkan…';

  @override
  String downloadHttpError(int code) {
    return 'Unduhan gagal: HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return 'Terunduh $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return 'Paket terunduh ke:\n$path\n\nKetuk “Pasang” untuk membuka installer sistem.\n\nJika Android memblokir aplikasi tidak dikenal, izinkan APRSlocus memasang aplikasi tidak dikenal di pengaturan sistem.';
  }

  @override
  String windowsInstallHelp(String path) {
    return 'Installer disimpan ke:\n$path\n\nKetuk “Jalankan sekarang” untuk meluncurkannya, atau buka folder penyimpanannya.';
  }

  @override
  String get openContainingFolder => 'Buka folder penyimpanan';

  @override
  String get runNow => 'Jalankan sekarang';

  @override
  String get cannotRunInstaller =>
      'Tidak dapat menjalankan installer. Buka manual dari folder penyimpanannya.';

  @override
  String get cannotLaunchInstaller =>
      'Tidak dapat meluncurkan installer. Buka paket secara manual.';

  @override
  String get openPackageManually => 'Buka paket di pengelola berkas';

  @override
  String cannotOpenPackage(String error) {
    return 'Tidak dapat membuka paket: $error';
  }

  @override
  String get installPermissionTitle => 'Izinkan pemasangan aplikasi';

  @override
  String get installPermissionDesc =>
      'APRSlocus tidak diizinkan memasang aplikasi.\n\nKetuk “Pengaturan”, izinkan aplikasi ini memasang aplikasi tidak dikenal, lalu kembali dan coba lagi.';

  @override
  String get recheck => 'Periksa lagi';

  @override
  String newVersionTitle(String version) {
    return 'Versi baru v$version tersedia';
  }

  @override
  String repoLatestTitle(String version) {
    return 'Versi terbaru repositori v$version';
  }

  @override
  String get checkingLatest => 'Memeriksa versi terbaru…';

  @override
  String get connectingGitCode => 'Menghubungkan ke GitCode';

  @override
  String get noReleaseNotes => 'Tidak ada catatan rilis';

  @override
  String noInstallerHistoryHint(String platform) {
    return 'Tidak ada paket $platform untuk rilis ini. Pilih versi yang bisa diunduh dari Riwayat.';
  }

  @override
  String get latestVersionLabel => 'Versi terbaru';

  @override
  String packageSize(String platform, String size) {
    return 'Ukuran paket $platform: $size';
  }

  @override
  String get updateContents => 'Yang baru';

  @override
  String get redownload => 'Unduh ulang';

  @override
  String get downloadInstaller => 'Unduh installer';

  @override
  String get downloadAndInstall => 'Unduh & pasang';

  @override
  String get localPackageExists => 'Paket sudah tersedia secara lokal';

  @override
  String get packageDeleted => 'Paket dihapus';

  @override
  String versionCount(int count) {
    return '$count versi';
  }

  @override
  String get noInstaller => 'Tidak ada paket';

  @override
  String get download => 'Unduh';

  @override
  String get viewChangelog => 'Lihat catatan rilis';

  @override
  String versionChangelog(String version) {
    return 'Catatan rilis v$version';
  }

  @override
  String get gotIt => 'Mengerti';

  @override
  String get leaveAction => 'Keluar';

  @override
  String localRepoVersion(Object latest, Object local) {
    return 'Lokal v$local · Repositori terbaru v$latest';
  }

  @override
  String get unverified => 'Belum diverifikasi';

  @override
  String get passcodeUnverifiedHint => '-1 (belum diverifikasi)';

  @override
  String get passcodeMessageWarning =>
      'Passcode login APRS-IS. Menggunakan -1 membuat pengiriman/penerimaan pesan tidak normal.';

  @override
  String get settingsStationIdentitySubtitle =>
      'Tanda panggil, SSID dan komentar';

  @override
  String get settingsDisplayInfoSubtitle => 'Simbol saya dan posisi saat ini';

  @override
  String get settingsLocSourceSubtitle => 'Pilih sumber posisi';

  @override
  String get settingsBeaconSubtitle => 'Interval kirim & isi laporan';

  @override
  String get settingsManualLocSubtitle =>
      'Input manual atau pilih di peta bila tidak ada posisi';

  @override
  String get settingsManualLocHint =>
      'Bila lokasi otomatis tidak tersedia, masukkan koordinat manual atau pilih di peta untuk pelaporan beacon dan perhitungan jarak stasiun.';

  @override
  String get settingsConnStatusSubtitle => 'Status dan info koneksi';

  @override
  String get settingsServerSubtitle => 'Server APRS-IS dan passcode';

  @override
  String get settingsFilterSubtitle => 'Pusat filter dan radius';

  @override
  String get settingsReceivePrefSubtitle =>
      'Terima berdasarkan negara/wilayah atau tanda panggil';

  @override
  String get settingsGeneralSubtitle => 'Tema, bahasa dan tampilan koordinat';

  @override
  String get settingsMapSubtitle => 'Jenis dan tampilan peta';

  @override
  String get settingsChatStatsSubtitle => 'Statistik pesan dan kontak';

  @override
  String get settingsChatManageSubtitle => 'Kontak dan data obrolan';

  @override
  String get settingsClearDataSubtitle => 'Hapus catatan lokal';

  @override
  String get settingsLabSubtitle => 'Fitur eksperimental';

  @override
  String get settingsDevSubtitle => 'Debug dan pengujian';

  @override
  String get settingsFilterHint =>
      'Hanya terima paket stasiun dalam jangkauan yang ditentukan';

  @override
  String get settingsReceivePrefHint =>
      'Selain filter jangkauan, terima stasiun berdasarkan grup negara/wilayah atau tanda panggil persis';

  @override
  String get settingsContribCodeOptimization => 'Optimasi kode';

  @override
  String get eggBg2hcb => 'Hidup ini penuh meong-meong~';

  @override
  String get deviceInfoTitle => 'Identifikasi perangkat';

  @override
  String get deviceToCall => 'To-call';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceClass => 'Kelas perangkat';

  @override
  String get deviceFilter => 'Filter perangkat';

  @override
  String get lookupQrz => 'Tanda panggil QRZ';

  @override
  String get lookupAprsFi => 'Posisi aprs.fi';

  @override
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => 'Halaman detail';

  @override
  String get aprsTvMap => 'Lihat di peta';

  @override
  String get linkOpenFailed => 'Tidak dapat membuka tautan';

  @override
  String get beaconAutoAskTitle => 'Tersambung — laporkan posisi otomatis?';

  @override
  String get beaconAutoAskDesc =>
      'Biarkan APRSlocus otomatis melaporkan posisi Anda (beacon) saat tersambung? Disarankan untuk penggunaan bergerak. Pilih tidak untuk hanya menerima (Anda tetap bisa mengirim manual kapan saja).';

  @override
  String get beaconAutoYes => 'Lapor otomatis';

  @override
  String get beaconAutoNo => 'Hanya terima';

  @override
  String get beaconOffChip => 'Lapor otomatis nonaktif';

  @override
  String get quickTrackCreate => 'Grup pelacakan baru';

  @override
  String get quickTrackHint =>
      'Pilih stasiun yang Anda terima, atau ketik tanda panggil — lacak langsung di peta, tanpa perlu grup obrolan.';

  @override
  String get quickTrackName => 'Nama (opsional)';

  @override
  String get quickTrackPickLabel => 'Pilih stasiun untuk dilacak';

  @override
  String get quickTrackNoStations =>
      'Belum ada stasiun diterima — ketik tanda panggil di bawah (pisahkan dengan koma)';

  @override
  String get quickTrackManualHint => 'Ketik tanda panggil, mis. BG7PGW,BG7LMW';

  @override
  String get quickTrackStart => 'Mulai melacak';

  @override
  String get quickTrackNeedMembers =>
      'Pilih atau ketik minimal satu tanda panggil';

  @override
  String get weatherPanelTitle => 'Cuaca · Tips Ham';

  @override
  String get weatherPanelSub => 'QWeather · Lokasi Saat Ini';

  @override
  String get weatherRefresh => 'Segarkan';

  @override
  String get weatherPowered => 'Didukung oleh QWeather · APRSlocus';

  @override
  String get hfTitle => 'Propagasi HF';

  @override
  String get hfSixMeter => 'Band 6m';

  @override
  String get hfEs => 'Es (E sporadis)';

  @override
  String get hfAurora => 'Aurora';

  @override
  String get hfF2 => 'Lapisan F2';

  @override
  String get hfBand => 'Band';

  @override
  String get hfDay => 'Siang';

  @override
  String get hfNight => 'Malam';

  @override
  String get hfNow => 'Sekarang';

  @override
  String get hfSfi => 'Fluks surya';

  @override
  String get hfKp => 'Indeks Kp';

  @override
  String get hfAIndex => 'Indeks A';

  @override
  String get hfSunspots => 'Bintik matahari';

  @override
  String get hfXray => 'Sinar-X';

  @override
  String get hfSolarWind => 'Angin surya';

  @override
  String get hfGeomag => 'Geomag';

  @override
  String get hfNoise => 'Derau';

  @override
  String get hfMuf => 'MUF';

  @override
  String get hfNoData => 'Belum ada data HF — dimuat otomatis saat daring';

  @override
  String get hfUnavailable => 'Layanan propagasi HF tidak tersedia';

  @override
  String get hfQGood => 'Bagus';

  @override
  String get hfQFair => 'Sedang';

  @override
  String get hfQPoor => 'Buruk';

  @override
  String get hfQClosed => 'Tertutup';

  @override
  String get hfPowered =>
      'Data propagasi oleh hamqsl.com (N0NBH) · rata-rata global, bukan pengukuran lokal';

  @override
  String get hfTipStorm =>
      'Badai geomagnetik (Kp≥5): jalur HF kutub meredup parah dan DX lintas kutub hampir hilang — coba jalur lintang rendah atau VHF/UHF lokal';

  @override
  String get hfTipGeomagActive =>
      'Medan geomagnetik tidak tenang: jalur HF lintang tinggi kurang stabil — beri waktu panggil lebih lama untuk DX';

  @override
  String get hfTipLowSfi =>
      'Aktivitas surya rendah (SFI<100): 15/12/10m siang kurang hidup — utamakan 40/30/20m';

  @override
  String get hfTipHighSfi =>
      'Aktivitas surya tinggi (SFI≥150): 15/12/10m siang berpeluang DX jarak jauh';

  @override
  String get hfTipHighNoise =>
      'Derau tinggi: sinyal lemah sulit disalin — persempit bandwidth, turunkan gain RF, pakai mode sempit bila perlu';

  @override
  String hfTipBandGood(String b) {
    return '$b terbuka: utamakan band ini untuk memanggil';
  }

  @override
  String hfTipBandPoor(String b) {
    return '$b buruk: coba band lain, atau tunggu garis kelabu fajar/senja';
  }

  @override
  String get weatherCurLoc => 'Lokasi saat ini';

  @override
  String get weatherNoLoc =>
      'Belum ada lokasi — aktifkan lokasi di Stasiun saya untuk melihat cuaca';

  @override
  String get weatherUnavail => 'Layanan cuaca tidak tersedia';

  @override
  String get weatherDataFail => 'Gagal mengambil data cuaca';

  @override
  String get weatherConnFail => 'Koneksi layanan cuaca gagal';

  @override
  String get weatherCloud => 'Awan';

  @override
  String get weatherDew => 'Titik embun';

  @override
  String get weatherHumidity => 'Kelembapan';

  @override
  String get weatherWindDir => 'Arah angin';

  @override
  String get weatherWindScale => 'Kekuatan angin';

  @override
  String get weatherWindSpeed => 'Kecepatan angin';

  @override
  String get weatherPressure => 'Tekanan';

  @override
  String get weatherVis => 'Jarak pandang';

  @override
  String get weatherPrecip => 'Presipitasi';

  @override
  String weatherFeels(String v) {
    return 'Terasa $v°';
  }

  @override
  String weatherObserved(String t) {
    return 'Diamati $t';
  }

  @override
  String get hamTitle => 'Tips radio amatir';

  @override
  String get hamNoData =>
      'Setelah cuaca dimuat, tips tentang pemasangan antena, operasi, dan keamanan petir akan muncul';

  @override
  String get hamStorm1 =>
      'Cuaca badai petir: JANGAN memasang atau mengoperasikan antena di luar ruangan! Lepaskan kabel feeder untuk menghindari kerusakan akibat lonjakan petir';

  @override
  String get hamStorm2 =>
      'Jika sudah terpasang, segera turunkan; beralih ke mendengarkan repeater / HF di dalam ruangan dan jaga peralatan tetap kering';

  @override
  String get hamRain =>
      'Presipitasi: bawa penutup hujan / kotak kering, segel konektor dengan selotip atau heat-shrink, dan pastikan kabel feeder tidak tergenang';

  @override
  String get hamCold =>
      'Dingin / salju: kapasitas baterai Li-ion turun — bawa baterai cadangan, simpan tetap hangat; perhatikan SWR bila terbentuk es pada antena';

  @override
  String hamWind(String w) {
    return 'Angin $w: pasang guy dan kokohkan antena; turunkan beam / long wire saat beres-beres';
  }

  @override
  String hamHot(String t) {
    return 'Panas $t°C: cukupi cairan; hindari transmisi daya penuh yang terlalu lama agar perangkat tidak panas berlebih';
  }

  @override
  String hamHumid(String h) {
    return 'Kelembapan $h%: uap air menurunkan isolasi dan efisiensi antena; rugi VHF/UHF lebih besar; jaga konektor bebas karat';
  }

  @override
  String hamFog(String v) {
    return 'Jarak pandang rendah ($v km): berkendara hati-hati; kabut dapat membentuk ducting — coba kontak VHF/UHF jarak jauh';
  }

  @override
  String get hamGood =>
      'Cuaca bagus untuk beroperasi! Coba repeater / simplex di VHF-UHF; ionosfer HF berubah pada malam hari';

  @override
  String hamWindExtra(String w) {
    return 'Angin $w: tetap pasang guy pada antena dan utamakan keselamatan di lapangan';
  }

  @override
  String get hamStorm3 =>
      'Petir mendekat: lepaskan kabel feeder antena dari rig, pindahkan ke pembumian di luar untuk melepas muatan, matikan dan cabut listrik agar lonjakan tidak masuk lewat AC atau LAN; jangan gunakan antena luar atau telepon kabel';

  @override
  String get hamStorm4 =>
      'QRN melonjak di sekitar badai petir dan noise floor HF naik; tunggu sekitar 30 menit setelah petir berhenti sebelum memasang antena dan memancar lagi';

  @override
  String get hamExtreme =>
      'Hujan sangat lebat: waspadai banjir bandang, genangan, dan batu jatuh — jangan memasang di tepi sungai atau tanah rendah; buat drip loop di tempat feeder masuk dinding';

  @override
  String hamGale(String w) {
    return 'Kekuatan angin $w: JANGAN memanjat tower atau tiang! Turunkan atau baringkan Yagi dan long wire, serta periksa guy, angkur, dan stay tiang';
  }

  @override
  String get hamIce =>
      'Es pada antena dan feeder menaikkan SWR dan menambah beban es: jangan memaksa daya penuh, periksa ketegangan guy dulu, dan tunggu es mencair sebelum operasi normal';

  @override
  String get hamFrost =>
      'Di bawah 0℃: kapasitas baterai litium turun tajam — simpan cadangan tetap hangat di kantong; waspadai radang dingin pada tangan dan wajah, bawa penghangat tangan';

  @override
  String get hamHeat2 =>
      'Panas membuat PA dan PSU mengalami derating: turunkan daya, perpendek transmisi berkelanjutan, dan pastikan ventilasi memadai';

  @override
  String get hamDust =>
      'Badai debu: pasir halus di konektor dan isolator menyebabkan kebocoran dan noise — gunakan penutup debu; gesekan kering menimbulkan listrik statis, jadi pastikan pembumian yang baik';

  @override
  String get hamAir =>
      'Kualitas udara buruk: kenakan masker di luar dan batasi aktivitas berat; lapisan polutan pada isolator antena menambah noise bocor, jadi bersihkan setelah selesai';

  @override
  String hamDew(String d) {
    return 'Selisih titik embun hanya $d℃ — udara mendekati jenuh: peralatan dan feeder bisa berembun; biarkan peralatan menghangat dan kering sebelum dinyalakan untuk menghindari korsleting';
  }

  @override
  String hamUV(String u) {
    return 'Indeks UV $u (tinggi): lindungi diri dari sengatan matahari saat kerja lapangan — paparan lama juga mempercepat penuaan jaket coax dan cable tie';
  }

  @override
  String hamLowPressure(String p) {
    return 'Tekanan rendah ($p hPa): cuaca cenderung tidak stabil — untuk sesi lapangan yang panjang, siapkan jalur evakuasi dan pantau peringatan terdekat';
  }

  @override
  String hamHighPressure(String p) {
    return 'Tekanan tinggi dan stabil ($p hPa): inversi mudah terbentuk dan ducting troposfer VHF/UHF mungkin terjadi — coba kontak langsung atau via repeater di luar jangkauan pandang';
  }

  @override
  String get hamGrayLine =>
      'Anda berada di grey line matahari terbit/terbenam: propagasi HF 20/40m memuncak sekarang — jendela emas untuk DX jarak jauh';

  @override
  String get hamNight =>
      'Lapisan D menghilang pada malam hari: absorpsi 80/40m turun dengan noise lebih rendah — bagus untuk komunikasi regional dan jarak jauh malam hari';

  @override
  String get hamRainFade =>
      'Hujan lebat menyebabkan rain fade di atas 1.2GHz: untuk microwave dan EME, turunkan ke band lebih rendah atau tunggu hujan reda';

  @override
  String get hamShower =>
      'Hujan lokal cepat datang dan pergi: bawa penutup hujan, perhatikan pergerakan awan, dan hentikan transmisi sebelum melepas feeder';

  @override
  String get hamLevelDanger => 'Keselamatan';

  @override
  String get hamLevelWarn => 'Perhatian';

  @override
  String get hamLevelGood => 'Propagasi';

  @override
  String get hamLevelTip => 'Tips';

  @override
  String hamMore(String n) {
    return 'Tampilkan semua $n tips';
  }

  @override
  String get hamLess => 'Ringkas';

  @override
  String get weatherForecast3 => 'Prakiraan 3 Hari';

  @override
  String get weatherDaily15 => 'Lihat cuaca 15 hari';

  @override
  String get weatherDaily15Title => 'Tren Cuaca 15 Hari';

  @override
  String get weatherToday => 'Hari ini';

  @override
  String get weatherTomorrow => 'Besok';

  @override
  String get weatherDayAfter => 'Lusa';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': 'Sen',
      '2': 'Sel',
      '3': 'Rab',
      '4': 'Kam',
      '5': 'Jum',
      '6': 'Sab',
      '7': 'Min',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => 'Matahari terbit';

  @override
  String get weatherSunset => 'Matahari terbenam';

  @override
  String get weatherUV => 'UV';

  @override
  String get weatherDetails => 'Detail';

  @override
  String get weatherAQIPrimary => 'Polutan utama';

  @override
  String get airExcellent => 'Sangat baik';

  @override
  String get airGood => 'Baik';

  @override
  String get airModerate => 'Polusi ringan';

  @override
  String get airUnhealthy => 'Polusi sedang';

  @override
  String get airVeryUnhealthy => 'Polusi berat';

  @override
  String get airHazardous => 'Polusi sangat berat';

  @override
  String get weatherAir => 'AQI';

  @override
  String get issStation => 'ISS';

  @override
  String get applyStationFilter => 'Terapkan filter stasiun ke peta';

  @override
  String get stationFilterOn => 'Difilter oleh panel stasiun';

  @override
  String get stationList => 'Daftar stasiun';

  @override
  String get statsPanel => 'Statistik';

  @override
  String get statsOverview => 'Ringkasan sistem';

  @override
  String get statsTotalRx => 'Paket RX';

  @override
  String get statsTotalTx => 'Paket TX';

  @override
  String get statsRate => 'Laju';

  @override
  String statsPerMin(String n) {
    return '$n/mnt';
  }

  @override
  String get statsStationsTotal => 'Stasiun';

  @override
  String get statsCap => 'Kapasitas';

  @override
  String get statsConn => 'Tautan';

  @override
  String get statsConnected => 'Tersambung';

  @override
  String get statsDisconnected => 'Offline';

  @override
  String get statsMyGrid => 'Grid saya';

  @override
  String get statsAprslocusUsers => 'Pengguna APRSlocus';

  @override
  String get statsFarthest => 'Terjauh';

  @override
  String get statsStatusDist => 'Rincian status';

  @override
  String get statsTypeDist => 'Rincian jenis';

  @override
  String get statsGridDist => 'Rincian grid';

  @override
  String get statsGridHint =>
      'Stasiun per field Maidenhead (4 karakter), diurutkan';

  @override
  String statsGridCount(String n) {
    return '$n grid';
  }

  @override
  String get statsGridEmpty => 'Belum ada posisi stasiun';

  @override
  String get statsDeviceDist => 'Kelas perangkat';

  @override
  String get statsOther => 'Metrik lainnya';

  @override
  String get statsAvgSpeed => 'Rata-rata kecepatan';

  @override
  String get statsLastHeard => 'Terakhir terdengar';

  @override
  String get statsPackets => 'Paket (terbaru)';

  @override
  String get statsNoData => 'Tidak ada data';

  @override
  String get noStationsFiltered =>
      'Tidak ada stasiun yang cocok dengan filter saat ini';

  @override
  String get noStationsFilteredHint =>
      'Filter atau jangkauan terima terlalu sempit. Kosongkan filter untuk mencoba lagi; jangkauan terima ada di Pengaturan.';

  @override
  String get clearStationFilter => 'Kosongkan filter';

  @override
  String get clearSearch => 'Kosongkan pencarian';

  @override
  String get activeConditions => 'Kondisi aktif';

  @override
  String get statsMovingCount => 'Bergerak';

  @override
  String get statsOnlineRate => 'Rasio online';

  @override
  String get statsGridCountLabel => 'Jumlah grid';

  @override
  String get maxPackets => 'Batas riwayat paket';

  @override
  String get maxPacketsTip =>
      'Berapa paket yang disimpan di halaman paket (bawaan 2000; lebih tinggi memakai lebih banyak memori)';

  @override
  String get maxTrackPts => 'Batas titik jejak';

  @override
  String get maxTrackPtsTip =>
      'Titik jejak per stasiun (bawaan 300; menentukan seberapa jauh jejak bisa ditelusuri; titik dicatat hanya setelah bergerak 20 m)';

  @override
  String get onlineWindow => 'Jendela online (menit)';

  @override
  String get onlineWindowTip =>
      'Stasiun tanpa laporan lebih lama dari ini dianggap offline (bawaan 5 menit)';

  @override
  String get chatRecords => 'Riwayat obrolan';

  @override
  String get chatRecordsCleared => 'Riwayat obrolan dihapus';

  @override
  String get deviceCat => 'Perangkat';

  @override
  String get deviceCatDesc => 'Peralatan radio · segera hadir';

  @override
  String get deviceSettings2 => 'Pengaturan perangkat';

  @override
  String get deviceSettingsSubtitle => 'Sambungkan peralatan radio Anda';

  @override
  String get underConstruction => 'Sedang dibangun — belum tersedia';

  @override
  String get underConstructionHint => 'Fitur ini masih dikembangkan. Nantikan.';

  @override
  String get storageLimit => 'Batas data';

  @override
  String get storageLimitSubtitle => 'Berapa banyak data yang disimpan lokal';

  @override
  String get connectionCard2 => 'Koneksi APRS-IS';

  @override
  String get immersiveMap => 'Peta imersif';

  @override
  String get immersiveMapTip =>
      'Gaya navigasi: berpusat pada Anda, heading-up, HUD sudut';

  @override
  String get headingUp => 'Heading ke atas';

  @override
  String get northUp => 'Utara ke atas';

  @override
  String get followMe => 'Ikuti saya';

  @override
  String get beaconCountdown => 'Beacon berikutnya';

  @override
  String get beaconOff => 'nonaktif';

  @override
  String get unlocated => 'Belum ada posisi';

  @override
  String get platform => 'Platform';

  @override
  String get nearbyStations => 'Stasiun sekitar';

  @override
  String get honorWall => 'Kehormatan';

  @override
  String get accountHonors => 'Kehormatan akun';

  @override
  String get achievementsSection => 'Pencapaian';

  @override
  String get notLit => 'Belum';

  @override
  String honorCriteriaLine(String c) {
    return 'Cara mendapatkan: $c';
  }

  @override
  String get badgeFallback => 'Lencana';

  @override
  String honoredBadges(String n, String m) {
    return '$n/$m lencana terbuka';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m pencapaian';
  }

  @override
  String get beaconNotConnected => 'Belum tersambung';

  @override
  String get beaconWaitingFix => 'Menunggu posisi';

  @override
  String get beaconSoon => 'Segera';

  @override
  String beaconNextIn(String s) {
    return 'Laporan berikutnya dalam $s';
  }

  @override
  String get beaconImminent => 'Segera melapor…';

  @override
  String get notifConnected => 'Tersambung';

  @override
  String get notifConnecting => 'Menghubungkan';

  @override
  String get notifDisconnected => 'Terputus';

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
  String get selectAll => 'Pilih semua';

  @override
  String get deselectAll => 'Batal pilih semua';

  @override
  String selectedCount(int n) {
    return '$n dipilih';
  }

  @override
  String deleteSelected(int n) {
    return 'Hapus ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return 'Hapus $n obrolan yang dipilih? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String get chatManageHint =>
      'Ketuk obrolan untuk memilih; tekan lama juga memilih';

  @override
  String conversationsDeleted(int n) {
    return '$n obrolan dihapus';
  }

  @override
  String get stationActions => 'Tindakan stasiun';

  @override
  String get deleteStation => 'Hapus stasiun';

  @override
  String deleteStationConfirm(String name) {
    return 'Hapus stasiun $name? Stasiun akan dihapus dari daftar dan muncul kembali jika paketnya diterima lagi.';
  }

  @override
  String get unfavorite => 'Hapus dari favorit';

  @override
  String get copyCallsign => 'Salin tanda panggil';

  @override
  String get callsignCopied => 'Tanda panggil disalin';

  @override
  String get stationDeleted => 'Stasiun dihapus';

  @override
  String get exportAdif => 'Ekspor ADIF';

  @override
  String get exportAdifDesc =>
      'Ekspor obrolan sebagai berkas log ADIF, dapat diimpor ke Log4OM, N3FJP, dan sejenisnya';

  @override
  String get export => 'Ekspor';

  @override
  String get adifHint =>
      'Setiap catatan hanya berisi tanda panggil dan waktu pesan pertama (UTC); mode dan band tidak disertakan';

  @override
  String get adifNoSelection => 'Pilih setidaknya satu obrolan untuk diekspor';

  @override
  String adifExported(int n) {
    return '$n catatan diekspor';
  }

  @override
  String get adifExportDone => 'Ekspor selesai';

  @override
  String get adifExportFailed =>
      'Ekspor gagal — periksa izin penyimpanan atau ruang kosong';

  @override
  String adifSavedTo(String path) {
    return 'Disimpan ke: $path';
  }

  @override
  String get adifCopyPath => 'Salin jalur';

  @override
  String get adifPathCopied => 'Jalur disalin';

  @override
  String get chatShortLabel => 'Pribadi';

  @override
  String get adifLogFile => 'Ekspor obrolan ke berkas log';

  @override
  String get adifOptions => 'Opsi ekspor';

  @override
  String get adifMode => 'Mode (MODE)';

  @override
  String get adifNotWritten => 'Kosongkan';

  @override
  String get adifModePkt => 'PKT (paket, disarankan)';

  @override
  String get adifModeFm => 'FM (suara)';

  @override
  String get adifModeData => 'DATA (data)';

  @override
  String get adifSubModeAprs => 'Tambahkan SUBMODE=APRS';

  @override
  String get adifBand => 'Band (BAND)';

  @override
  String get adifStripSsid => 'Tulis panggilan dasar saja (hapus -SSID)';

  @override
  String get adifPreview => 'Pratinjau (catatan yang akan ditulis)';

  @override
  String get adifModeRequiredHint =>
      'Sebagian besar logbook (termasuk QRZ) mewajibkan MODE; tanpa itu akan ditolak';

  @override
  String get adifFreq => 'Frekuensi (FREQ)';

  @override
  String get adifFreqHint => 'Dalam MHz; kosongkan untuk tidak menulis';

  @override
  String get adifFreqInvalid => 'Masukkan angka dalam MHz, mis. 144.640';

  @override
  String get sysTitle => 'Status sistem';

  @override
  String get sysLinkOff => 'Nonaktif';

  @override
  String sysRx(String n) {
    return 'Rx $n';
  }

  @override
  String sysTx(String n) {
    return 'Tx $n';
  }

  @override
  String sysBeacon(String t) {
    return 'Beacon $t';
  }

  @override
  String sysStations(String n) {
    return 'Stasiun $n';
  }

  @override
  String get sysFixOk => 'Terlokasi';

  @override
  String get sysLinkAudio => 'Audio';

  @override
  String get sysEmpty =>
      'Buka APRSlocus dan sambungkan untuk melihat status di sini';

  @override
  String get backupTitle => 'Cadangkan & pulihkan';

  @override
  String get backupSubtitle => 'Ekspor atau impor pengaturan dan data';

  @override
  String get backupEntryDesc => 'Kemas pengaturan dan data ke JSON';

  @override
  String get backupDesc =>
      'Cadangan berupa berkas JSON yang bisa dipulihkan setelah ganti perangkat atau pasang ulang. Impor menimpa per grup dan tidak bisa dibatalkan.';

  @override
  String get backupExport => 'Ekspor cadangan';

  @override
  String get backupExportDesc => 'Pilih isi, lalu simpan ke berkas atau salin';

  @override
  String get backupExportToFile => 'Simpan ke berkas';

  @override
  String get backupCopyJson => 'Salin ke papan klip';

  @override
  String get backupExportDone => 'Cadangan diekspor';

  @override
  String get backupExportFailed =>
      'Ekspor gagal — periksa izin penyimpanan atau ruang yang tersisa';

  @override
  String get backupCopyDone => 'Cadangan disalin';

  @override
  String backupSavedTo(String path) {
    return 'Disimpan ke: $path';
  }

  @override
  String get backupCatSettings => 'Pengaturan';

  @override
  String get backupCatSettingsDesc =>
      'Stasiun, beacon, peta, filter, sumber, server';

  @override
  String get backupCatStations => 'Stasiun & kontak';

  @override
  String get backupCatStationsDesc => 'Favorit, kontak manual, dan catatannya';

  @override
  String get backupCatMessages => 'Pesan';

  @override
  String get backupCatMessagesDesc => 'Pesan langsung dan posisi baca';

  @override
  String get backupCatChats => 'Obrolan grup';

  @override
  String get backupCatChatsDesc => 'Grup, anggota, dan status baca';

  @override
  String get backupCatTranslate => 'Pengaturan terjemahan';

  @override
  String get backupCatTranslateDesc => 'Penyedia, kunci, dan preferensi bahasa';

  @override
  String get backupCatHonors => 'Pencapaian & kehormatan';

  @override
  String get backupCatHonorsDesc => 'Bukaan, penghitung, dan lencana bawaan';

  @override
  String backupItems(int n) {
    return '$n item';
  }

  @override
  String get backupSelectAll => 'Pilih semua';

  @override
  String get backupNoSelection => 'Pilih minimal satu grup';

  @override
  String get backupImport => 'Impor cadangan';

  @override
  String get backupImportDesc =>
      'Pilih berkas JSON cadangan yang pernah diekspor';

  @override
  String get backupPickFile => 'Pilih berkas cadangan';

  @override
  String get backupPaste => 'Tempel dari papan klip';

  @override
  String get backupPasteEmpty => 'Tidak ada teks di papan klip';

  @override
  String get backupPreview => 'Isi cadangan';

  @override
  String backupFromVersion(String v) {
    return 'Dari versi $v';
  }

  @override
  String backupExportedAt(String t) {
    return 'Diekspor $t';
  }

  @override
  String get backupImportSelected => 'Impor yang dipilih';

  @override
  String get backupImportConfirmTitle => 'Impor cadangan ini?';

  @override
  String get backupImportConfirm =>
      'Grup terpilih akan ditimpa dan tidak bisa dibatalkan. Sebaiknya ekspor dulu data saat ini.';

  @override
  String backupImported(int n) {
    return 'Mengimpor $n item';
  }

  @override
  String backupSkipped(int n) {
    return 'Melewati $n entri tak dikenal';
  }

  @override
  String get backupImportNothing =>
      'Cadangan tidak punya data untuk grup terpilih';

  @override
  String get backupRestartTitle => 'Impor selesai';

  @override
  String get backupRestartHint =>
      'Data tersimpan; mulai ulang aplikasi agar semuanya berlaku (pencapaian, terjemahan, koneksi server).';

  @override
  String get backupRestartNow => 'Keluar aplikasi';

  @override
  String get backupLater => 'Nanti';

  @override
  String get backupSecurityTip =>
      'Cadangan berisi callsign, passcode server, dan kunci API — simpan dengan aman.';

  @override
  String get backupWebHint =>
      'Di web, gunakan “salin / tempel dari papan klip”.';

  @override
  String get backupErrNotJson => 'Berkas bukan JSON yang valid';

  @override
  String get backupErrNotBackup => 'Ini bukan berkas cadangan APRSlocus';

  @override
  String get backupErrSchemaNewer =>
      'Cadangan berasal dari APRSlocus versi lebih baru — perbarui aplikasi dulu';

  @override
  String get backupErrEmpty => 'Cadangan tidak berisi apa pun untuk diimpor';

  @override
  String get backupErrTooLarge =>
      'Cadangan melebihi 32 MB dan tidak bisa dibaca';

  @override
  String get backupErrRead => 'Gagal membaca berkas cadangan';

  @override
  String get backupErrUnsupported =>
      'Memilih berkas tidak didukung di sini — tempel dari papan klip';

  @override
  String get themeTitle => 'Tema';

  @override
  String get themeEntryDesc => 'Sesuaikan warna, ikon, dan teks';

  @override
  String get themeSubtitle => 'Jadikan warna, ikon, dan teks umum milik Anda';

  @override
  String get themePresets => 'Preset & tema saya';

  @override
  String get themePresetTag => 'preset';

  @override
  String get themeActive => 'Sedang dipakai';

  @override
  String get themePresetDefault => 'Bawaan';

  @override
  String get themePresetOcean => 'Samudra';

  @override
  String get themePresetForest => 'Hutan';

  @override
  String get themePresetMidnight => 'Tengah malam';

  @override
  String get themePresetSunset => 'Senja';

  @override
  String get themePresetContrast => 'Kontras tinggi';

  @override
  String get themeBuiltinHint =>
      'Preset tidak bisa diubah — salin dulu ke tema Anda';

  @override
  String get themeColors => 'Warna';

  @override
  String get themeColorsDesc =>
      'Timpa warna satu per satu; sisanya tetap bawaan';

  @override
  String get themeRadius => 'Sudut kartu';

  @override
  String get themeRadiusDesc =>
      'Berlaku untuk kartu dan kolom isian (lencana kecil tidak)';

  @override
  String get themeIcons => 'Ikon';

  @override
  String get themeIconsDesc =>
      'Ganti ikon tab bawah dan pintu masuk pengaturan';

  @override
  String get themeTexts => 'Teks';

  @override
  String get themeTextsDesc =>
      'Timpa teks umum (tombol dan pesan galat sengaja dikecualikan)';

  @override
  String get themeNew => 'Tema baru';

  @override
  String get themeDuplicate => 'Salin ke tema saya';

  @override
  String get themeRename => 'Ganti nama';

  @override
  String get themeDelete => 'Hapus tema';

  @override
  String themeDeleteConfirm(String name) {
    return 'Hapus tema “$name”? Tidak bisa dibatalkan.';
  }

  @override
  String get themeReset => 'Setel ulang';

  @override
  String get themeResetAll => 'Setel ulang tema ini';

  @override
  String get themeSaved => 'Tema disimpan';

  @override
  String get themeNameHint => 'Nama tema';

  @override
  String get themePickColor => 'Pilih warna';

  @override
  String get themePickIcon => 'Pilih ikon';

  @override
  String get themePickIconSearch => 'Cari nama ikon';

  @override
  String get themeEditText => 'Ubah teks';

  @override
  String get themeTextHint => 'Kosongkan untuk menyetel ulang';

  @override
  String get themeIconImport => 'Impor gambar';

  @override
  String get themeIconImportHint => 'PNG/JPG/WebP/GIF/BMP/SVG, maks 2 MB';

  @override
  String themeIconImportDone(String name) {
    return 'Ikon diimpor: $name';
  }

  @override
  String get themeIconWebHint =>
      'Di web tidak bisa mengimpor gambar — gunakan pustaka ikon bawaan';

  @override
  String get themeIconErrFormat =>
      'Format gambar tidak didukung (PNG/JPG/WebP/GIF/BMP/SVG)';

  @override
  String get themeIconErrTooLarge => 'Gambar melebihi 2 MB — kompres dulu';

  @override
  String get themeIconErrFailed => 'Gagal mengimpor ikon';

  @override
  String get themeIconErrUnsupported =>
      'Platform ini tidak mendukung impor gambar';

  @override
  String get themeIo => 'Impor & ekspor';

  @override
  String get themeIoDesc =>
      'Tema berupa teks JSON — bisa dibagikan dan diedit manual';

  @override
  String get themeExport => 'Ekspor tema ini';

  @override
  String get themeExportAll => 'Ekspor semua tema';

  @override
  String get themeImport => 'Impor tema';

  @override
  String get themeImportPaste => 'Impor dari papan klip';

  @override
  String themeImportDone(int n) {
    return 'Mengimpor $n tema';
  }

  @override
  String get themeErrNotJson => 'Berkas bukan JSON yang valid';

  @override
  String get themeErrNotTheme => 'Ini bukan berkas tema APRSlocus';

  @override
  String get themeErrSchemaNewer =>
      'Tema berasal dari APRSlocus versi lebih baru — perbarui aplikasi dulu';

  @override
  String get themeErrEmpty => 'Berkas tidak berisi tema yang bisa dipakai';

  @override
  String get themeFixedPrimary =>
      'Tema aktif mengunci warna utama — ubah di halaman Tema';

  @override
  String get themeTokenPrimary => 'Utama';

  @override
  String get themeTokenSurface => 'Permukaan kartu';

  @override
  String get themeTokenBackground => 'Latar halaman';

  @override
  String get themeTokenBackgroundSoft => 'Latar sekunder';

  @override
  String get themeTokenTextPrimary => 'Teks utama';

  @override
  String get themeTokenTextSecondary => 'Teks sekunder';

  @override
  String get themeTokenTextMuted => 'Teks redup';

  @override
  String get themeTokenDivider => 'Pemisah';

  @override
  String get themeTokenSuccess => 'Berhasil / daring';

  @override
  String get themeTokenWarning => 'Peringatan';

  @override
  String get themeTokenDanger => 'Bahaya / luring';

  @override
  String get themeTokenInfo => 'Info / aksen';

  @override
  String get themeBg => 'Gambar latar';

  @override
  String get themeBgDesc =>
      'Pakai gambar sebagai latar; kartu otomatis jadi semi-transparan';

  @override
  String get themeBgPick => 'Pilih gambar';

  @override
  String get themeBgReplace => 'Ganti gambar';

  @override
  String get themeBgRemove => 'Hapus latar';

  @override
  String get themeBgOpacity => 'Opasitas';

  @override
  String get themeBgOpacityDesc =>
      'Sekaligus mengatur kerudung: makin tinggi makin terlihat gambarnya, makin berisiko teks tak terbaca';

  @override
  String get themeBgBlur => 'Buram';

  @override
  String get themeBgBlurDesc =>
      'Pemburaman menghapus detail foto agar teks di atasnya tetap terbaca';

  @override
  String get themeBgFit => 'Mode isian';

  @override
  String get themeBgFitCover => 'Penuh';

  @override
  String get themeBgFitContain => 'Muat';

  @override
  String get themeBgFitStretch => 'Regangkan';

  @override
  String get themeBgFitTile => 'Ubin';

  @override
  String get themeBgNone => 'Belum diatur';

  @override
  String get themeBgErrTooLarge =>
      'Latar melebihi 8 MB — kompres dulu (ikon dibatasi 2 MB)';

  @override
  String get themeBgLocalOnly =>
      'Gambar tetap di perangkat ini: berkas tema hanya mencatat referensi, bukan gambarnya, jadi penerima akan melihat tema tanpa latar.';

  @override
  String get themeBgDisabledHint =>
      'Tema ini tanpa gambar latar; latarnya warna solid';

  @override
  String get themeExportWithImages => 'Sertakan gambar saat ekspor';

  @override
  String themeExportWithImagesHint(String size) {
    return 'Ekspor akan menyertakan gambar (sekitar $size), jadi penerima melihat latar dan ikon yang sama. Berkasnya jadi tidak lagi bisa diedit manual.';
  }

  @override
  String get themeExportNoImages =>
      'Tema ini tidak memakai gambar; ekspornya hanya berisi warna dan teks';

  @override
  String get themeExportClipboardTooBig =>
      'Gambarnya terlalu besar untuk papan klip — gunakan “Ekspor semua tema” untuk menyimpan berkas';

  @override
  String themeImportImagesSkipped(int n) {
    return '$n gambar tidak diimpor (terlalu besar atau tidak didukung)';
  }

  @override
  String get backupThemeImagesHint =>
      'Cadangan akan menyertakan gambar yang dipakai tema. Tanpanya, tema yang dipulihkan kembali ke ikon bawaan.';

  @override
  String get backupThemeImagesOff =>
      'Tanpa gambar: cadangan lebih kecil, tetapi tema yang dipulihkan kehilangan latar dan ikon kustom';

  @override
  String get themeSurface => 'Permukaan kartu';

  @override
  String get themeSurfaceDesc => 'Saat ada latar, seberapa transparan kartu';

  @override
  String get themeSurfaceAlpha => 'Opasitas (makin rendah makin tembus)';

  @override
  String get themeSurfaceAlphaDesc =>
      'Sekitar 0.85 menutup sekaligus memperlihatkan latar; di bawah 0.6 teks mulai kabur';

  @override
  String get themeSurfaceNoBg =>
      'Belum ada gambar latar, jadi belum terlihat efeknya';

  @override
  String get themeLayout => 'Kerapatan & font';

  @override
  String get themeLayoutDesc =>
      'Hanya memengaruhi padding kartu dan kolom isian';

  @override
  String get themeDensity => 'Kerapatan';

  @override
  String get themeDensityCompact => 'Padat';

  @override
  String get themeDensityNormal => 'Normal';

  @override
  String get themeDensityComfortable => 'Longgar';

  @override
  String get themeDensityHint =>
      'Ini mengubah padding kartu; jika ada yang tak berubah, jaraknya ditetapkan terpisah';

  @override
  String get themeFont => 'Font';

  @override
  String get themeFontDefault => 'Bawaan sistem';

  @override
  String get themeFontSystem => 'Font antarmuka sistem';

  @override
  String get themeFontMono => 'Monospace';

  @override
  String get themeFontHint =>
      'Hanya memakai font sistem; jika tidak ada, otomatis dialihkan';

  @override
  String get themeTabs => 'Warna aksen';

  @override
  String get themeTabsDesc => 'Gradien kartu masuk dan warna aksen per tab';

  @override
  String get themeUniformAccent => 'Samakan warna kartu masuk';

  @override
  String get themeAccentFrom => 'Awal gradien';

  @override
  String get themeAccentTo => 'Akhir gradien';

  @override
  String get themeOverridden => 'Kustom';

  @override
  String get themeFollowsPrimary => 'Ikut warna utama';

  @override
  String get themeBgAlign => 'Perataan';

  @override
  String get themeAlignCenter => 'Tengah';

  @override
  String get themeAlignTop => 'Atas';

  @override
  String get themeAlignBottom => 'Bawah';

  @override
  String get themeAlignLeft => 'Kiri';

  @override
  String get themeAlignRight => 'Kanan';

  @override
  String get themeAlignTopLeft => 'Kiri atas';

  @override
  String get themeAlignTopRight => 'Kanan atas';

  @override
  String get themeAlignBottomLeft => 'Kiri bawah';

  @override
  String get themeAlignBottomRight => 'Kanan bawah';

  @override
  String get themeBgScale => 'Skala';

  @override
  String get themeBgScaleDesc =>
      '1.0 = ukuran asli; perbesar untuk menampilkan sebagian';

  @override
  String get themeAuthor => 'Penulis';

  @override
  String get themeDescription => 'Deskripsi';

  @override
  String get themeSkinInfo => 'Info skin';

  @override
  String get themeSkinInfoDesc => 'Keduanya ikut saat skin dibagikan';

  @override
  String get themeAuthorHint => 'Callsign atau nama panggilan Anda';

  @override
  String get themeDescHint => 'Satu baris tentang skin ini';

  @override
  String get themePreviewSwatches => 'Contoh warna';

  @override
  String get themePresetGraphite => 'Grafit';

  @override
  String get themePresetSakura => 'Sakura';

  @override
  String get themePresetTerminal => 'Terminal';

  @override
  String get themePresetAmber => 'Amber';

  @override
  String get sysRecentLabel => 'Terakhir diterima';

  @override
  String get audioWavImportAction => 'Pilih berkas WAV';

  @override
  String get audioWavExportToDownloads => 'Ekspor ke Unduhan';

  @override
  String audioWavSavedTo(String path) {
    return 'Disimpan ke $path';
  }

  @override
  String get audioWavCopyPath => 'Salin jalur';

  @override
  String get audioWavPathCopied => 'Jalur disalin';

  @override
  String get audioWavCanceled => 'Dibatalkan';

  @override
  String get audioWavVerifyFailed =>
      'Pemeriksaan gagal: audio yang dibuat tidak dapat didekode';

  @override
  String get audioWavMobileHint =>
      'Android tidak bisa menulis jalur bebas: berkas disimpan di Unduhan/APRSlocusAudio — salin ke PC untuk Direwolf atau radio';

  @override
  String get audioWavPickHint => 'Di desktop, isi jalur WAV di bawah';

  @override
  String get audioTxLevel => 'Level TX';

  @override
  String get audioTxLevelTip =>
      'Sebelum mengirim, volume media dinaikkan maksimum dan mikrofon dijeda; puncak terlalu rendah atau terpotong membuat lawan tidak bisa mendekode';

  @override
  String audioTxPeak(int p, String sec, int flags) {
    return 'Puncak $p% · ${sec}s · preamble $flags flag';
  }

  @override
  String get audioTxLevelClip =>
      'Terpotong: turunkan amplitudo di bawah 0.8 (menimbulkan harmonisa)';

  @override
  String get audioTxLevelLow =>
      'Level rendah: lawan mungkin tidak bisa mendekode — naikkan amplitudo dan volume';

  @override
  String get audioWiringHint =>
      'Gunakan kabel audio ke radio (keluaran headphone → konektor data/mikrofon). Speaker ponsel meredam 2200 Hz dengan buruk, jadi kopling akustik hampir tidak pernah bisa didekode. Jika lawan adalah Direwolf, uji dulu dengan WAV hasil ekspor: kalau itu bisa, masalahnya di jalur audio, bukan protokol';

  @override
  String packetLimitRf(int bytes, int max) {
    return 'Paket $bytes B · batas bingkai RF $max B';
  }

  @override
  String packetLimitIs(int bytes) {
    return 'Paket $bytes B · batas baris APRS-IS 512 B';
  }

  @override
  String get packetTcpipWarning =>
      'Mengandung TCPIP*: akan dihapus di RF (jalur itu milik APRS-IS)';

  @override
  String packetSent(String line) {
    return 'Diteruskan ke tautan: $line';
  }

  @override
  String packetSendFailed(String err) {
    return 'Tidak terkirim: $err';
  }

  @override
  String get tncSerialBaud => 'Kecepatan baud serial (bd)';

  @override
  String get tncSerialBaudTip =>
      'Kabel serial USB dan port data radio harus sama kecepatannya, kalau tidak satu byte pun tidak akan lewat. Nilai umum: 9600 / 19200 / 38400 / 57600 / 115200. Bluetooth SPP tidak punya konsep baud, jadi ini diabaikan untuk perangkat Bluetooth.';

  @override
  String get tncSerialBaudHint =>
      'Kecepatan baru berlaku setelah menghubungkan ulang (mengirim parameter akan menyambung ulang sekali secara otomatis)';

  @override
  String get tncSerialBaudBluetooth =>
      'Perangkat yang tertaut adalah Bluetooth: Bluetooth SPP tidak punya konsep baud, jadi pengaturan ini tidak berpengaruh';

  @override
  String get uiMaterial => 'Material antarmuka';

  @override
  String get uiMaterialDesc =>
      'Membuat kartu, bilah, dan dialog tembus pandang, dengan buram nyata di belakangnya';

  @override
  String get uiMaterialOff => 'Mati (padat)';

  @override
  String get uiMaterialOffDesc => 'Permukaan padat, sama seperti sebelumnya';

  @override
  String get uiMaterialGlass => 'Kaca buram';

  @override
  String get uiMaterialGlassDesc =>
      'Lebih tembus pandang dengan buram lebih kuat, seperti Acrylic Windows 11';

  @override
  String get uiMaterialMica => 'Mica';

  @override
  String get uiMaterialMicaDesc =>
      'Lebih padat dengan buram ringan dan sedikit warna aksen, seperti Mica Windows 11';

  @override
  String get uiMaterialHint =>
      'Material hanya memengaruhi permukaan aplikasi (kartu, bilah, dialog, lapisan peta); bukan transparansi jendela. Buram memakai GPU, jadi di perangkat lama mungkin terasa kurang lancar dibanding Mati.';

  @override
  String get uiMaterialBgHint =>
      'Tema ini memakai gambar latar, jadi material tidak menambah latar sendiri dan hanya membuat bilah serta lapisan menjadi buram.';

  @override
  String get uiMaterialPreview => 'Pratinjau';
}
