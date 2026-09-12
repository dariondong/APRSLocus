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
      'Secara bawaan hanya tanda panggil Tiongkok yang diterima. Tambahkan negara/wilayah lain sesuai kebutuhan';

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
  String get datumGcj => 'GCJ-02 (AMAP)';

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
}
