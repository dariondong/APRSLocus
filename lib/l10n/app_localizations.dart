import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus'**
  String get appName;

  /// No description provided for @appName_desc.
  ///
  /// In zh, this message translates to:
  /// **'应用名称'**
  String get appName_desc;

  /// No description provided for @ok.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get ok;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @next.
  ///
  /// In zh, this message translates to:
  /// **'下一步'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In zh, this message translates to:
  /// **'完成并连接'**
  String get finish;

  /// No description provided for @previous.
  ///
  /// In zh, this message translates to:
  /// **'上一步'**
  String get previous;

  /// No description provided for @search.
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @about.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// No description provided for @logout.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get logout;

  /// No description provided for @retry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// No description provided for @all.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get all;

  /// No description provided for @online.
  ///
  /// In zh, this message translates to:
  /// **'在线'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In zh, this message translates to:
  /// **'离线'**
  String get offline;

  /// No description provided for @moving.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get moving;

  /// No description provided for @emergency.
  ///
  /// In zh, this message translates to:
  /// **'紧急'**
  String get emergency;

  /// No description provided for @fixed.
  ///
  /// In zh, this message translates to:
  /// **'固定'**
  String get fixed;

  /// No description provided for @infrastructure.
  ///
  /// In zh, this message translates to:
  /// **'中继'**
  String get infrastructure;

  /// No description provided for @weather.
  ///
  /// In zh, this message translates to:
  /// **'气象'**
  String get weather;

  /// No description provided for @fmo.
  ///
  /// In zh, this message translates to:
  /// **'FMO'**
  String get fmo;

  /// No description provided for @mobile.
  ///
  /// In zh, this message translates to:
  /// **'车载'**
  String get mobile;

  /// No description provided for @favorite.
  ///
  /// In zh, this message translates to:
  /// **'收藏'**
  String get favorite;

  /// No description provided for @grid.
  ///
  /// In zh, this message translates to:
  /// **'网格'**
  String get grid;

  /// No description provided for @callsign.
  ///
  /// In zh, this message translates to:
  /// **'呼号'**
  String get callsign;

  /// No description provided for @speed.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speed;

  /// No description provided for @altitude.
  ///
  /// In zh, this message translates to:
  /// **'高度'**
  String get altitude;

  /// No description provided for @course.
  ///
  /// In zh, this message translates to:
  /// **'航向'**
  String get course;

  /// No description provided for @distance.
  ///
  /// In zh, this message translates to:
  /// **'距离'**
  String get distance;

  /// No description provided for @bearing.
  ///
  /// In zh, this message translates to:
  /// **'方位角'**
  String get bearing;

  /// No description provided for @lastSeen.
  ///
  /// In zh, this message translates to:
  /// **'最近活跃'**
  String get lastSeen;

  /// No description provided for @latitude.
  ///
  /// In zh, this message translates to:
  /// **'纬度'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In zh, this message translates to:
  /// **'经度'**
  String get longitude;

  /// No description provided for @station.
  ///
  /// In zh, this message translates to:
  /// **'台站'**
  String get station;

  /// No description provided for @stations.
  ///
  /// In zh, this message translates to:
  /// **'台站'**
  String get stations;

  /// No description provided for @messages.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get messages;

  /// No description provided for @packets.
  ///
  /// In zh, this message translates to:
  /// **'数据包'**
  String get packets;

  /// No description provided for @map.
  ///
  /// In zh, this message translates to:
  /// **'地图'**
  String get map;

  /// No description provided for @home.
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get home;

  /// No description provided for @connection.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connection;

  /// No description provided for @connected.
  ///
  /// In zh, this message translates to:
  /// **'已连接'**
  String get connected;

  /// No description provided for @disconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接'**
  String get disconnected;

  /// No description provided for @connecting.
  ///
  /// In zh, this message translates to:
  /// **'连接中'**
  String get connecting;

  /// No description provided for @reconnect.
  ///
  /// In zh, this message translates to:
  /// **'重新连接'**
  String get reconnect;

  /// No description provided for @server.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get server;

  /// No description provided for @port.
  ///
  /// In zh, this message translates to:
  /// **'端口'**
  String get port;

  /// No description provided for @passcode.
  ///
  /// In zh, this message translates to:
  /// **'Passcode'**
  String get passcode;

  /// No description provided for @beacon.
  ///
  /// In zh, this message translates to:
  /// **'位置信标'**
  String get beacon;

  /// No description provided for @beaconInterval.
  ///
  /// In zh, this message translates to:
  /// **'上报间隔(秒)'**
  String get beaconInterval;

  /// No description provided for @nextBeacon.
  ///
  /// In zh, this message translates to:
  /// **'下次上报'**
  String get nextBeacon;

  /// No description provided for @beaconsSent.
  ///
  /// In zh, this message translates to:
  /// **'信标发送次数'**
  String get beaconsSent;

  /// No description provided for @filter.
  ///
  /// In zh, this message translates to:
  /// **'接收范围过滤'**
  String get filter;

  /// No description provided for @filterRadius.
  ///
  /// In zh, this message translates to:
  /// **'过滤半径(km)'**
  String get filterRadius;

  /// No description provided for @maxStations.
  ///
  /// In zh, this message translates to:
  /// **'最大台站数'**
  String get maxStations;

  /// No description provided for @receiveFilter.
  ///
  /// In zh, this message translates to:
  /// **'接收呼号筛选'**
  String get receiveFilter;

  /// No description provided for @receiveCountries.
  ///
  /// In zh, this message translates to:
  /// **'国家/地区'**
  String get receiveCountries;

  /// No description provided for @receiveOthers.
  ///
  /// In zh, this message translates to:
  /// **'其他台站'**
  String get receiveOthers;

  /// No description provided for @darkMode.
  ///
  /// In zh, this message translates to:
  /// **'深色模式'**
  String get darkMode;

  /// No description provided for @themeColor.
  ///
  /// In zh, this message translates to:
  /// **'主题颜色'**
  String get themeColor;

  /// No description provided for @language.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// No description provided for @languageZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageZh;

  /// No description provided for @languageEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @displaySettings.
  ///
  /// In zh, this message translates to:
  /// **'显示设置'**
  String get displaySettings;

  /// No description provided for @mapType.
  ///
  /// In zh, this message translates to:
  /// **'地图类型'**
  String get mapType;

  /// No description provided for @unit.
  ///
  /// In zh, this message translates to:
  /// **'单位'**
  String get unit;

  /// No description provided for @coordDatum.
  ///
  /// In zh, this message translates to:
  /// **'坐标基准'**
  String get coordDatum;

  /// No description provided for @stationSettings.
  ///
  /// In zh, this message translates to:
  /// **'电台设置'**
  String get stationSettings;

  /// No description provided for @connectionSettings.
  ///
  /// In zh, this message translates to:
  /// **'连接设置'**
  String get connectionSettings;

  /// No description provided for @chatSettings.
  ///
  /// In zh, this message translates to:
  /// **'聊天设置'**
  String get chatSettings;

  /// No description provided for @dataSettings.
  ///
  /// In zh, this message translates to:
  /// **'数据设置'**
  String get dataSettings;

  /// No description provided for @advancedSettings.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get advancedSettings;

  /// No description provided for @sponsors.
  ///
  /// In zh, this message translates to:
  /// **'赞助与鸣谢'**
  String get sponsors;

  /// No description provided for @sponsorsThanks.
  ///
  /// In zh, this message translates to:
  /// **'感谢每一位支持者'**
  String get sponsorsThanks;

  /// No description provided for @send.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get send;

  /// No description provided for @receive.
  ///
  /// In zh, this message translates to:
  /// **'接收'**
  String get receive;

  /// No description provided for @clear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// No description provided for @copy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// No description provided for @copied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get copied;

  /// No description provided for @version.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// No description provided for @location.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get location;

  /// No description provided for @gpsStatus.
  ///
  /// In zh, this message translates to:
  /// **'GPS 状态'**
  String get gpsStatus;

  /// No description provided for @myLocation.
  ///
  /// In zh, this message translates to:
  /// **'我的位置'**
  String get myLocation;

  /// No description provided for @track.
  ///
  /// In zh, this message translates to:
  /// **'轨迹'**
  String get track;

  /// No description provided for @forwardingPath.
  ///
  /// In zh, this message translates to:
  /// **'转发路径'**
  String get forwardingPath;

  /// No description provided for @relatedStations.
  ///
  /// In zh, this message translates to:
  /// **'相关台站'**
  String get relatedStations;

  /// No description provided for @openInMap.
  ///
  /// In zh, this message translates to:
  /// **'在地图查看'**
  String get openInMap;

  /// No description provided for @navigate.
  ///
  /// In zh, this message translates to:
  /// **'导航'**
  String get navigate;

  /// No description provided for @messageSent.
  ///
  /// In zh, this message translates to:
  /// **'消息已发送'**
  String get messageSent;

  /// No description provided for @enterMessage.
  ///
  /// In zh, this message translates to:
  /// **'输入消息'**
  String get enterMessage;

  /// No description provided for @noData.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据'**
  String get noData;

  /// No description provided for @searchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索呼号 / 类型 / 网格 / 备注…'**
  String get searchHint;

  /// No description provided for @notFound.
  ///
  /// In zh, this message translates to:
  /// **'未找到台站'**
  String get notFound;

  /// No description provided for @totalStations.
  ///
  /// In zh, this message translates to:
  /// **'总数'**
  String get totalStations;

  /// No description provided for @sortBy.
  ///
  /// In zh, this message translates to:
  /// **'排序'**
  String get sortBy;

  /// No description provided for @sortCall.
  ///
  /// In zh, this message translates to:
  /// **'呼号'**
  String get sortCall;

  /// No description provided for @sortRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近'**
  String get sortRecent;

  /// No description provided for @sortDistance.
  ///
  /// In zh, this message translates to:
  /// **'距离'**
  String get sortDistance;

  /// No description provided for @sortStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get sortStatus;

  /// No description provided for @typeFilter.
  ///
  /// In zh, this message translates to:
  /// **'类型筛选'**
  String get typeFilter;

  /// No description provided for @aprslocusOnly.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus'**
  String get aprslocusOnly;

  /// No description provided for @confirmDelete.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除吗？'**
  String get confirmDelete;

  /// No description provided for @confirmRestartOobe.
  ///
  /// In zh, this message translates to:
  /// **'将重新进入首次启动向导，可重新设置呼号、接收地区等。\n当前设置不会丢失，完成向导后继续使用。'**
  String get confirmRestartOobe;

  /// No description provided for @restartWizard.
  ///
  /// In zh, this message translates to:
  /// **'重新运行设置向导'**
  String get restartWizard;

  /// No description provided for @restartWizardTitle.
  ///
  /// In zh, this message translates to:
  /// **'重新运行设置向导？'**
  String get restartWizardTitle;

  /// No description provided for @oobeFilterTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择接收地区'**
  String get oobeFilterTitle;

  /// No description provided for @oobeFilterDesc.
  ///
  /// In zh, this message translates to:
  /// **'默认只接收中国呼号台站，可按需添加其他国家/地区'**
  String get oobeFilterDesc;

  /// No description provided for @oobeWelcomeTitle.
  ///
  /// In zh, this message translates to:
  /// **'欢迎使用 APRSlocus'**
  String get oobeWelcomeTitle;

  /// No description provided for @oobeWelcomeRealMap.
  ///
  /// In zh, this message translates to:
  /// **'实时地图'**
  String get oobeWelcomeRealMap;

  /// No description provided for @oobeWelcomeGps.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位上报'**
  String get oobeWelcomeGps;

  /// No description provided for @oobeWelcomeMsg.
  ///
  /// In zh, this message translates to:
  /// **'APRS 消息'**
  String get oobeWelcomeMsg;

  /// No description provided for @oobeWelcomeIs.
  ///
  /// In zh, this message translates to:
  /// **'接入 APRS-IS'**
  String get oobeWelcomeIs;

  /// No description provided for @oobeCallTitle.
  ///
  /// In zh, this message translates to:
  /// **'你的呼号'**
  String get oobeCallTitle;

  /// No description provided for @oobeSymbolTitle.
  ///
  /// In zh, this message translates to:
  /// **'选择台站符号'**
  String get oobeSymbolTitle;

  /// No description provided for @oobeServerTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接 APRS-IS 服务器'**
  String get oobeServerTitle;

  /// No description provided for @weatherData.
  ///
  /// In zh, this message translates to:
  /// **'气象数据'**
  String get weatherData;

  /// No description provided for @fmoInfo.
  ///
  /// In zh, this message translates to:
  /// **'FMO 台站信息'**
  String get fmoInfo;

  /// No description provided for @aprslocusInfo.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus 信息'**
  String get aprslocusInfo;

  /// No description provided for @locationInfo.
  ///
  /// In zh, this message translates to:
  /// **'位置信息'**
  String get locationInfo;

  /// No description provided for @recentPackets.
  ///
  /// In zh, this message translates to:
  /// **'最近数据包'**
  String get recentPackets;

  /// No description provided for @quickActions.
  ///
  /// In zh, this message translates to:
  /// **'快捷操作'**
  String get quickActions;

  /// No description provided for @copyCoords.
  ///
  /// In zh, this message translates to:
  /// **'复制坐标'**
  String get copyCoords;

  /// No description provided for @copyGrid.
  ///
  /// In zh, this message translates to:
  /// **'复制网格'**
  String get copyGrid;

  /// No description provided for @sender.
  ///
  /// In zh, this message translates to:
  /// **'发送方'**
  String get sender;

  /// No description provided for @time.
  ///
  /// In zh, this message translates to:
  /// **'时间'**
  String get time;

  /// No description provided for @message.
  ///
  /// In zh, this message translates to:
  /// **'消息'**
  String get message;

  /// No description provided for @groupChat.
  ///
  /// In zh, this message translates to:
  /// **'群聊'**
  String get groupChat;

  /// No description provided for @newGroup.
  ///
  /// In zh, this message translates to:
  /// **'新建群聊'**
  String get newGroup;

  /// No description provided for @sendTo.
  ///
  /// In zh, this message translates to:
  /// **'发送至'**
  String get sendTo;

  /// No description provided for @filterRule.
  ///
  /// In zh, this message translates to:
  /// **'过滤规则'**
  String get filterRule;

  /// No description provided for @saveAndApply.
  ///
  /// In zh, this message translates to:
  /// **'保存并应用过滤'**
  String get saveAndApply;

  /// No description provided for @useMyLocation.
  ///
  /// In zh, this message translates to:
  /// **'用我的位置作为过滤中心'**
  String get useMyLocation;

  /// No description provided for @noFixYet.
  ///
  /// In zh, this message translates to:
  /// **'尚未定位，无法获取当前位置'**
  String get noFixYet;

  /// No description provided for @invalidCoords.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的经纬度和半径'**
  String get invalidCoords;

  /// No description provided for @filterSaved.
  ///
  /// In zh, this message translates to:
  /// **'过滤已保存并应用'**
  String get filterSaved;

  /// No description provided for @stationsShown.
  ///
  /// In zh, this message translates to:
  /// **'台站'**
  String get stationsShown;

  /// No description provided for @settingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'配置电台、定位与连接'**
  String get settingsDesc;

  /// No description provided for @radioCat.
  ///
  /// In zh, this message translates to:
  /// **'电台'**
  String get radioCat;

  /// No description provided for @radioCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'呼号 · SSID · 符号'**
  String get radioCatDesc;

  /// No description provided for @beaconCat.
  ///
  /// In zh, this message translates to:
  /// **'定位上报'**
  String get beaconCat;

  /// No description provided for @beaconCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'GPS · 信标 · 手动定位'**
  String get beaconCatDesc;

  /// No description provided for @connectionCat.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connectionCat;

  /// No description provided for @connectionCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'服务器 · 过滤范围'**
  String get connectionCatDesc;

  /// No description provided for @displayCat.
  ///
  /// In zh, this message translates to:
  /// **'显示'**
  String get displayCat;

  /// No description provided for @displayCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'坐标 · 主题'**
  String get displayCatDesc;

  /// No description provided for @chatCat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get chatCat;

  /// No description provided for @chatCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'记录 · 联系人'**
  String get chatCatDesc;

  /// No description provided for @dataCat.
  ///
  /// In zh, this message translates to:
  /// **'数据'**
  String get dataCat;

  /// No description provided for @dataCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除本地数据'**
  String get dataCatDesc;

  /// No description provided for @advancedCat.
  ///
  /// In zh, this message translates to:
  /// **'高级'**
  String get advancedCat;

  /// No description provided for @advancedCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'实验室 · 开发者'**
  String get advancedCatDesc;

  /// No description provided for @updateCat.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get updateCat;

  /// No description provided for @updateCatDesc.
  ///
  /// In zh, this message translates to:
  /// **'检查新版本'**
  String get updateCatDesc;

  /// No description provided for @checkUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkUpdate;

  /// No description provided for @myStationSettings.
  ///
  /// In zh, this message translates to:
  /// **'我的电台'**
  String get myStationSettings;

  /// No description provided for @myStationSettingsDesc.
  ///
  /// In zh, this message translates to:
  /// **'呼号 · SSID · 符号 · 信标'**
  String get myStationSettingsDesc;

  /// No description provided for @oobeWelcomeDesc.
  ///
  /// In zh, this message translates to:
  /// **'开始配置你的 APRS 电台'**
  String get oobeWelcomeDesc;

  /// No description provided for @oobeCallDesc.
  ///
  /// In zh, this message translates to:
  /// **'输入你的呼号'**
  String get oobeCallDesc;

  /// No description provided for @oobeSymbolDesc.
  ///
  /// In zh, this message translates to:
  /// **'符号代表台站类型，会随位置信标一起发送'**
  String get oobeSymbolDesc;

  /// No description provided for @oobeServerDesc.
  ///
  /// In zh, this message translates to:
  /// **'连接后接收全球 APRS 台站数据，可保持默认配置直接使用'**
  String get oobeServerDesc;

  /// No description provided for @wizard.
  ///
  /// In zh, this message translates to:
  /// **'设置向导'**
  String get wizard;

  /// No description provided for @setStep.
  ///
  /// In zh, this message translates to:
  /// **'步骤'**
  String get setStep;

  /// No description provided for @chooseSymbol.
  ///
  /// In zh, this message translates to:
  /// **'选择台站符号'**
  String get chooseSymbol;

  /// No description provided for @settingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'地图坐标与显示偏好'**
  String get settingsSubtitle;

  /// No description provided for @stationSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'呼号、符号与信标'**
  String get stationSettingsSubtitle;

  /// No description provided for @connectionSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'APRS-IS 服务器与接收范围'**
  String get connectionSettingsSubtitle;

  /// No description provided for @chatSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'消息记录与联系人'**
  String get chatSettingsSubtitle;

  /// No description provided for @dataSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'本地数据管理'**
  String get dataSettingsSubtitle;

  /// No description provided for @advancedSettingsSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'实验室与开发者工具'**
  String get advancedSettingsSubtitle;

  /// No description provided for @stationListTitle.
  ///
  /// In zh, this message translates to:
  /// **'台站列表'**
  String get stationListTitle;

  /// No description provided for @filters.
  ///
  /// In zh, this message translates to:
  /// **'筛选'**
  String get filters;

  /// No description provided for @clearAll.
  ///
  /// In zh, this message translates to:
  /// **'全部清除'**
  String get clearAll;

  /// No description provided for @statusFilter.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get statusFilter;

  /// No description provided for @typeGroup.
  ///
  /// In zh, this message translates to:
  /// **'类型'**
  String get typeGroup;

  /// No description provided for @appFilter.
  ///
  /// In zh, this message translates to:
  /// **'软件'**
  String get appFilter;

  /// No description provided for @mapMenu.
  ///
  /// In zh, this message translates to:
  /// **'地图菜单'**
  String get mapMenu;

  /// No description provided for @mapTypeTitle.
  ///
  /// In zh, this message translates to:
  /// **'地图类型'**
  String get mapTypeTitle;

  /// No description provided for @selectMapType.
  ///
  /// In zh, this message translates to:
  /// **'选择地图类型'**
  String get selectMapType;

  /// No description provided for @showTrails.
  ///
  /// In zh, this message translates to:
  /// **'显示轨迹'**
  String get showTrails;

  /// No description provided for @showStations.
  ///
  /// In zh, this message translates to:
  /// **'显示台站'**
  String get showStations;

  /// No description provided for @aboutTitle.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get aboutTitle;

  /// No description provided for @aboutSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'APRS 定位追踪与地图'**
  String get aboutSubtitle;

  /// No description provided for @author.
  ///
  /// In zh, this message translates to:
  /// **'作者'**
  String get author;

  /// No description provided for @features.
  ///
  /// In zh, this message translates to:
  /// **'功能特性'**
  String get features;

  /// No description provided for @openSource.
  ///
  /// In zh, this message translates to:
  /// **'开源致谢'**
  String get openSource;

  /// No description provided for @feedback.
  ///
  /// In zh, this message translates to:
  /// **'用户反馈'**
  String get feedback;

  /// No description provided for @qqGroup.
  ///
  /// In zh, this message translates to:
  /// **'QQ 交流群'**
  String get qqGroup;

  /// No description provided for @projectRepo.
  ///
  /// In zh, this message translates to:
  /// **'项目仓库'**
  String get projectRepo;

  /// No description provided for @testMembers.
  ///
  /// In zh, this message translates to:
  /// **'测试成员'**
  String get testMembers;

  /// No description provided for @aiSupport.
  ///
  /// In zh, this message translates to:
  /// **'AI 算力支持'**
  String get aiSupport;

  /// No description provided for @copyAppInfo.
  ///
  /// In zh, this message translates to:
  /// **'复制应用信息'**
  String get copyAppInfo;

  /// No description provided for @appInfoCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制应用信息'**
  String get appInfoCopied;

  /// No description provided for @enterCallsign.
  ///
  /// In zh, this message translates to:
  /// **'请输入你的呼号'**
  String get enterCallsign;

  /// No description provided for @enterValidCall.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效呼号'**
  String get enterValidCall;

  /// No description provided for @stationSettings2.
  ///
  /// In zh, this message translates to:
  /// **'电台设置'**
  String get stationSettings2;

  /// No description provided for @beaconSettings.
  ///
  /// In zh, this message translates to:
  /// **'定位上报'**
  String get beaconSettings;

  /// No description provided for @displaySettings2.
  ///
  /// In zh, this message translates to:
  /// **'显示设置'**
  String get displaySettings2;

  /// No description provided for @chatSettings2.
  ///
  /// In zh, this message translates to:
  /// **'聊天设置'**
  String get chatSettings2;

  /// No description provided for @dataSettings2.
  ///
  /// In zh, this message translates to:
  /// **'数据设置'**
  String get dataSettings2;

  /// No description provided for @advancedSettings2.
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get advancedSettings2;

  /// No description provided for @connectionSettings2.
  ///
  /// In zh, this message translates to:
  /// **'连接设置'**
  String get connectionSettings2;

  /// No description provided for @myCallsign.
  ///
  /// In zh, this message translates to:
  /// **'我的呼号'**
  String get myCallsign;

  /// No description provided for @beaconEnabled.
  ///
  /// In zh, this message translates to:
  /// **'启用位置信标'**
  String get beaconEnabled;

  /// No description provided for @smartBeacon.
  ///
  /// In zh, this message translates to:
  /// **'智能信标(移动加速)'**
  String get smartBeacon;

  /// No description provided for @packetConsole.
  ///
  /// In zh, this message translates to:
  /// **'数据包控制台'**
  String get packetConsole;

  /// No description provided for @rawMode.
  ///
  /// In zh, this message translates to:
  /// **'原始模式'**
  String get rawMode;

  /// No description provided for @parsedMode.
  ///
  /// In zh, this message translates to:
  /// **'解析模式'**
  String get parsedMode;

  /// No description provided for @position.
  ///
  /// In zh, this message translates to:
  /// **'位置'**
  String get position;

  /// No description provided for @statusType.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get statusType;

  /// No description provided for @objectType.
  ///
  /// In zh, this message translates to:
  /// **'对象'**
  String get objectType;

  /// No description provided for @packetStats.
  ///
  /// In zh, this message translates to:
  /// **'收 {rx} · 发 {tx} · {ppm}/分'**
  String packetStats(Object ppm, Object rx, Object tx);

  /// No description provided for @searchPacket.
  ///
  /// In zh, this message translates to:
  /// **'搜索呼号、目的地或原始内容…'**
  String get searchPacket;

  /// No description provided for @noMatchingPackets.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的数据包'**
  String get noMatchingPackets;

  /// No description provided for @inject.
  ///
  /// In zh, this message translates to:
  /// **'注入'**
  String get inject;

  /// No description provided for @manualInject.
  ///
  /// In zh, this message translates to:
  /// **'手动注入 APRS 数据包'**
  String get manualInject;

  /// No description provided for @injected.
  ///
  /// In zh, this message translates to:
  /// **'已注入数据包'**
  String get injected;

  /// No description provided for @clearedPackets.
  ///
  /// In zh, this message translates to:
  /// **'已清除数据包'**
  String get clearedPackets;

  /// No description provided for @clearPackets.
  ///
  /// In zh, this message translates to:
  /// **'清除数据包'**
  String get clearPackets;

  /// No description provided for @noPositionInfo.
  ///
  /// In zh, this message translates to:
  /// **'{call} 暂无位置信息（数据包未含位置）'**
  String noPositionInfo(Object call);

  /// No description provided for @copiedPacket.
  ///
  /// In zh, this message translates to:
  /// **'已复制数据包'**
  String get copiedPacket;

  /// No description provided for @mapPickMode.
  ///
  /// In zh, this message translates to:
  /// **'地图选点模式'**
  String get mapPickMode;

  /// No description provided for @mapPickDesc.
  ///
  /// In zh, this message translates to:
  /// **'点击地图选择我的位置'**
  String get mapPickDesc;

  /// No description provided for @foundStations.
  ///
  /// In zh, this message translates to:
  /// **'找到 {count} 台匹配「{q}」'**
  String foundStations(Object count, Object q);

  /// No description provided for @tapMapHint.
  ///
  /// In zh, this message translates to:
  /// **'点击地图查看台站 · 双指缩放'**
  String get tapMapHint;

  /// No description provided for @myLocationPanel.
  ///
  /// In zh, this message translates to:
  /// **'我的位置 · {call}'**
  String myLocationPanel(Object call);

  /// No description provided for @speedLabel.
  ///
  /// In zh, this message translates to:
  /// **'速度'**
  String get speedLabel;

  /// No description provided for @courseLabel.
  ///
  /// In zh, this message translates to:
  /// **'航向'**
  String get courseLabel;

  /// No description provided for @beaconIntervalLabel.
  ///
  /// In zh, this message translates to:
  /// **'上报间隔'**
  String get beaconIntervalLabel;

  /// No description provided for @beaconsSentLabel.
  ///
  /// In zh, this message translates to:
  /// **'已上报'**
  String get beaconsSentLabel;

  /// No description provided for @nextBeaconLabel.
  ///
  /// In zh, this message translates to:
  /// **'下次上报'**
  String get nextBeaconLabel;

  /// No description provided for @positionBeacon.
  ///
  /// In zh, this message translates to:
  /// **'位置信标 · 网格 {grid}'**
  String positionBeacon(Object grid);

  /// No description provided for @manualBeacon.
  ///
  /// In zh, this message translates to:
  /// **'手动上报'**
  String get manualBeacon;

  /// No description provided for @mapPickNow.
  ///
  /// In zh, this message translates to:
  /// **'地图选点'**
  String get mapPickNow;

  /// No description provided for @pickedCoord.
  ///
  /// In zh, this message translates to:
  /// **'已在地图选点 · {lat}, {lng} · 网格 {grid}'**
  String pickedCoord(Object grid, Object lat, Object lng);

  /// No description provided for @onlineCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 在线'**
  String onlineCount(Object count);

  /// No description provided for @movingCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 移动'**
  String movingCount(Object count);

  /// No description provided for @stationCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 台站'**
  String stationCount(Object count);

  /// No description provided for @locateMe.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get locateMe;

  /// No description provided for @layerFilter.
  ///
  /// In zh, this message translates to:
  /// **'图层筛选'**
  String get layerFilter;

  /// No description provided for @showAll.
  ///
  /// In zh, this message translates to:
  /// **'全部显示'**
  String get showAll;

  /// No description provided for @otherType.
  ///
  /// In zh, this message translates to:
  /// **'其他'**
  String get otherType;

  /// No description provided for @zoomLevel.
  ///
  /// In zh, this message translates to:
  /// **'缩放 {z}'**
  String zoomLevel(Object z);

  /// No description provided for @datumGcj.
  ///
  /// In zh, this message translates to:
  /// **'高德火星'**
  String get datumGcj;

  /// No description provided for @datumWgs.
  ///
  /// In zh, this message translates to:
  /// **'WGS-84'**
  String get datumWgs;

  /// No description provided for @distKm.
  ///
  /// In zh, this message translates to:
  /// **'距离 {d}km'**
  String distKm(Object d);

  /// No description provided for @noStationInView.
  ///
  /// In zh, this message translates to:
  /// **'该区域暂无台站 · 点击显示全部'**
  String get noStationInView;

  /// No description provided for @tapToView.
  ///
  /// In zh, this message translates to:
  /// **'点击查看'**
  String get tapToView;

  /// No description provided for @beaconNow.
  ///
  /// In zh, this message translates to:
  /// **'手动上报'**
  String get beaconNow;

  /// No description provided for @meLabel.
  ///
  /// In zh, this message translates to:
  /// **'我'**
  String get meLabel;

  /// No description provided for @mapZoomIn.
  ///
  /// In zh, this message translates to:
  /// **'放大'**
  String get mapZoomIn;

  /// No description provided for @mapZoomOut.
  ///
  /// In zh, this message translates to:
  /// **'缩小'**
  String get mapZoomOut;

  /// No description provided for @mapHome.
  ///
  /// In zh, this message translates to:
  /// **'回到中心'**
  String get mapHome;

  /// No description provided for @mapLocate.
  ///
  /// In zh, this message translates to:
  /// **'定位'**
  String get mapLocate;

  /// No description provided for @mapLayers.
  ///
  /// In zh, this message translates to:
  /// **'图层'**
  String get mapLayers;

  /// No description provided for @featureLiveMap.
  ///
  /// In zh, this message translates to:
  /// **'高德地图'**
  String get featureLiveMap;

  /// No description provided for @featureLiveMapDesc.
  ///
  /// In zh, this message translates to:
  /// **'GCJ-02 坐标，流畅的缩放与拖拽体验'**
  String get featureLiveMapDesc;

  /// No description provided for @featureGps.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位'**
  String get featureGps;

  /// No description provided for @featureGpsDesc.
  ///
  /// In zh, this message translates to:
  /// **'原生 Android 定位，无需 Google 服务'**
  String get featureGpsDesc;

  /// No description provided for @featureBeacon.
  ///
  /// In zh, this message translates to:
  /// **'信标发送'**
  String get featureBeacon;

  /// No description provided for @featureBeaconDesc.
  ///
  /// In zh, this message translates to:
  /// **'自定义内容、频率、符号，支持 APRS 标准格式'**
  String get featureBeaconDesc;

  /// No description provided for @featureMsg.
  ///
  /// In zh, this message translates to:
  /// **'消息收发'**
  String get featureMsg;

  /// No description provided for @featureMsgDesc.
  ///
  /// In zh, this message translates to:
  /// **'瀑布流 + 会话模式，支持中文和自动应答'**
  String get featureMsgDesc;

  /// No description provided for @featureAutoConnect.
  ///
  /// In zh, this message translates to:
  /// **'自动连接'**
  String get featureAutoConnect;

  /// No description provided for @featureAutoConnectDesc.
  ///
  /// In zh, this message translates to:
  /// **'公共服务器自动连接，后台保持在线'**
  String get featureAutoConnectDesc;

  /// No description provided for @featureLayerFilter.
  ///
  /// In zh, this message translates to:
  /// **'图层筛选'**
  String get featureLayerFilter;

  /// No description provided for @featureLayerFilterDesc.
  ///
  /// In zh, this message translates to:
  /// **'按类型筛选：移动、固定、中继、气象、FMO'**
  String get featureLayerFilterDesc;

  /// No description provided for @featureFmo.
  ///
  /// In zh, this message translates to:
  /// **'FMO 台站'**
  String get featureFmo;

  /// No description provided for @featureFmoDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动识别 FMO 数据，显示结构化信息'**
  String get featureFmoDesc;

  /// No description provided for @osFlutter.
  ///
  /// In zh, this message translates to:
  /// **'Flutter'**
  String get osFlutter;

  /// No description provided for @osFlutterDesc.
  ///
  /// In zh, this message translates to:
  /// **'Google 跨平台 UI 框架'**
  String get osFlutterDesc;

  /// No description provided for @osAmap.
  ///
  /// In zh, this message translates to:
  /// **'高德地图'**
  String get osAmap;

  /// No description provided for @osAmapDesc.
  ///
  /// In zh, this message translates to:
  /// **'地图瓦片服务'**
  String get osAmapDesc;

  /// No description provided for @osAprs.
  ///
  /// In zh, this message translates to:
  /// **'APRS-IS'**
  String get osAprs;

  /// No description provided for @osAprsDesc.
  ///
  /// In zh, this message translates to:
  /// **'全球 APRS 数据网络'**
  String get osAprsDesc;

  /// No description provided for @osHam.
  ///
  /// In zh, this message translates to:
  /// **'业余无线电'**
  String get osHam;

  /// No description provided for @osHamDesc.
  ///
  /// In zh, this message translates to:
  /// **'所有 APRS 爱好者的贡献'**
  String get osHamDesc;

  /// No description provided for @authorName.
  ///
  /// In zh, this message translates to:
  /// **'Darion'**
  String get authorName;

  /// No description provided for @authorCall.
  ///
  /// In zh, this message translates to:
  /// **'呼号'**
  String get authorCall;

  /// No description provided for @website.
  ///
  /// In zh, this message translates to:
  /// **'网站'**
  String get website;

  /// No description provided for @sponsorAuthor.
  ///
  /// In zh, this message translates to:
  /// **'作者 BG7LZQ'**
  String get sponsorAuthor;

  /// No description provided for @sponsorAuthorItems.
  ///
  /// In zh, this message translates to:
  /// **'利用课余时间开发维护本项目'**
  String get sponsorAuthorItems;

  /// No description provided for @sponsorGroup.
  ///
  /// In zh, this message translates to:
  /// **'STUDENT HAMS 群组'**
  String get sponsorGroup;

  /// No description provided for @sponsorGroupItems.
  ///
  /// In zh, this message translates to:
  /// **'感谢群组的资金赞助支持'**
  String get sponsorGroupItems;

  /// No description provided for @sponsorBgp.
  ///
  /// In zh, this message translates to:
  /// **'BG7PGW'**
  String get sponsorBgp;

  /// No description provided for @sponsorBgpItems.
  ///
  /// In zh, this message translates to:
  /// **'感谢赞助的蜜雪冰城一杯 🧋'**
  String get sponsorBgpItems;

  /// No description provided for @sponsorEvery.
  ///
  /// In zh, this message translates to:
  /// **'每一位支持者'**
  String get sponsorEvery;

  /// No description provided for @sponsorEveryItems.
  ///
  /// In zh, this message translates to:
  /// **'你们的每一份支持都是动力'**
  String get sponsorEveryItems;

  /// No description provided for @donateWechat.
  ///
  /// In zh, this message translates to:
  /// **'微信赞赏'**
  String get donateWechat;

  /// No description provided for @donateWechatDesc.
  ///
  /// In zh, this message translates to:
  /// **'长按保存赞赏码 · 点击放大'**
  String get donateWechatDesc;

  /// No description provided for @donateAlipay.
  ///
  /// In zh, this message translates to:
  /// **'支付宝赞赏'**
  String get donateAlipay;

  /// No description provided for @donateAlipayDesc.
  ///
  /// In zh, this message translates to:
  /// **'联系作者获取赞赏码'**
  String get donateAlipayDesc;

  /// No description provided for @nonprofitNote.
  ///
  /// In zh, this message translates to:
  /// **'本项目为非盈利学习交流项目\n赞助仅用于服务器与开发成本'**
  String get nonprofitNote;

  /// No description provided for @myStation.
  ///
  /// In zh, this message translates to:
  /// **'我的电台'**
  String get myStation;

  /// No description provided for @callSsid.
  ///
  /// In zh, this message translates to:
  /// **'呼号 · SSID'**
  String get callSsid;

  /// No description provided for @ssid.
  ///
  /// In zh, this message translates to:
  /// **'SSID'**
  String get ssid;

  /// No description provided for @ssidDesc.
  ///
  /// In zh, this message translates to:
  /// **'SSID 是呼号后缀用于标识设备，如 BG7ABC-9 中的 -9'**
  String get ssidDesc;

  /// No description provided for @callComment.
  ///
  /// In zh, this message translates to:
  /// **'台站备注'**
  String get callComment;

  /// No description provided for @callCommentHint.
  ///
  /// In zh, this message translates to:
  /// **'信标发送时的备注内容'**
  String get callCommentHint;

  /// No description provided for @callSymbol.
  ///
  /// In zh, this message translates to:
  /// **'台站符号'**
  String get callSymbol;

  /// No description provided for @callSymbolDesc.
  ///
  /// In zh, this message translates to:
  /// **'符号随位置信标一起发送'**
  String get callSymbolDesc;

  /// No description provided for @autoReply.
  ///
  /// In zh, this message translates to:
  /// **'自动应答'**
  String get autoReply;

  /// No description provided for @sendBeacon.
  ///
  /// In zh, this message translates to:
  /// **'发送信标'**
  String get sendBeacon;

  /// No description provided for @mapTypeDesc.
  ///
  /// In zh, this message translates to:
  /// **'「地图 2.0（矢量）」使用客户端实时矢量渲染，数据量小、缩放清晰；高德矢量/卫星为在线栅格瓦片。'**
  String get mapTypeDesc;

  /// No description provided for @msgHistory.
  ///
  /// In zh, this message translates to:
  /// **'消息记录'**
  String get msgHistory;

  /// No description provided for @statistics.
  ///
  /// In zh, this message translates to:
  /// **'统计'**
  String get statistics;

  /// No description provided for @clearData.
  ///
  /// In zh, this message translates to:
  /// **'清除数据'**
  String get clearData;

  /// No description provided for @favorites.
  ///
  /// In zh, this message translates to:
  /// **'收藏/手动'**
  String get favorites;

  /// No description provided for @favoriteStations.
  ///
  /// In zh, this message translates to:
  /// **'收藏台站'**
  String get favoriteStations;

  /// No description provided for @manualStations.
  ///
  /// In zh, this message translates to:
  /// **'手动台站'**
  String get manualStations;

  /// No description provided for @wgs84.
  ///
  /// In zh, this message translates to:
  /// **'WGS-84'**
  String get wgs84;

  /// No description provided for @gcj02.
  ///
  /// In zh, this message translates to:
  /// **'高德火星'**
  String get gcj02;

  /// No description provided for @onlyWgs84.
  ///
  /// In zh, this message translates to:
  /// **'仅标准 WGS-84'**
  String get onlyWgs84;

  /// No description provided for @contactList.
  ///
  /// In zh, this message translates to:
  /// **'联系人'**
  String get contactList;

  /// No description provided for @contactDesc.
  ///
  /// In zh, this message translates to:
  /// **'消息/联系人相关的过滤规则'**
  String get contactDesc;

  /// No description provided for @dataClearDesc.
  ///
  /// In zh, this message translates to:
  /// **'清除消息、数据包、台站等本地数据'**
  String get dataClearDesc;

  /// No description provided for @advancedDesc.
  ///
  /// In zh, this message translates to:
  /// **'实验室与开发者工具'**
  String get advancedDesc;

  /// No description provided for @labDesc.
  ///
  /// In zh, this message translates to:
  /// **'实验室功能仍在测试中，可能影响使用体验。默认锁定竖屏，开启后支持横屏。'**
  String get labDesc;

  /// No description provided for @systemLog.
  ///
  /// In zh, this message translates to:
  /// **'系统日志'**
  String get systemLog;

  /// No description provided for @devDesc.
  ///
  /// In zh, this message translates to:
  /// **'开发者调试工具'**
  String get devDesc;

  /// No description provided for @simData.
  ///
  /// In zh, this message translates to:
  /// **'启用模拟数据（演示台站/数据包）'**
  String get simData;

  /// No description provided for @rxTx.
  ///
  /// In zh, this message translates to:
  /// **'收包 / 发包'**
  String get rxTx;

  /// No description provided for @stationCount2.
  ///
  /// In zh, this message translates to:
  /// **'台站数量'**
  String get stationCount2;

  /// No description provided for @appInfo.
  ///
  /// In zh, this message translates to:
  /// **'应用信息'**
  String get appInfo;

  /// No description provided for @clearMessages.
  ///
  /// In zh, this message translates to:
  /// **'清空全部聊天记录'**
  String get clearMessages;

  /// No description provided for @clearPackets2.
  ///
  /// In zh, this message translates to:
  /// **'清除数据包'**
  String get clearPackets2;

  /// No description provided for @clearStations.
  ///
  /// In zh, this message translates to:
  /// **'清除台站列表'**
  String get clearStations;

  /// No description provided for @clearCache.
  ///
  /// In zh, this message translates to:
  /// **'清除缓存'**
  String get clearCache;

  /// No description provided for @resetAll.
  ///
  /// In zh, this message translates to:
  /// **'重置全部设置'**
  String get resetAll;

  /// No description provided for @resetAllDesc.
  ///
  /// In zh, this message translates to:
  /// **'恢复出厂设置'**
  String get resetAllDesc;

  /// No description provided for @dataPersistence.
  ///
  /// In zh, this message translates to:
  /// **'台站持久化'**
  String get dataPersistence;

  /// No description provided for @autoSaveStations.
  ///
  /// In zh, this message translates to:
  /// **'自动保存台站数据'**
  String get autoSaveStations;

  /// No description provided for @gridFormat.
  ///
  /// In zh, this message translates to:
  /// **'网格格式'**
  String get gridFormat;

  /// No description provided for @coordsFormat.
  ///
  /// In zh, this message translates to:
  /// **'坐标格式'**
  String get coordsFormat;

  /// No description provided for @appVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get appVersion;

  /// No description provided for @appVersionDesc.
  ///
  /// In zh, this message translates to:
  /// **'当前应用版本'**
  String get appVersionDesc;

  /// No description provided for @stationDetail.
  ///
  /// In zh, this message translates to:
  /// **'台站详情'**
  String get stationDetail;

  /// No description provided for @backToTop.
  ///
  /// In zh, this message translates to:
  /// **'回到顶部'**
  String get backToTop;

  /// No description provided for @installApk.
  ///
  /// In zh, this message translates to:
  /// **'安装 APRSlocus'**
  String get installApk;

  /// No description provided for @install.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get install;

  /// No description provided for @cancelInstall.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancelInstall;

  /// No description provided for @openFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开目录'**
  String get openFolder;

  /// No description provided for @browse.
  ///
  /// In zh, this message translates to:
  /// **'浏览'**
  String get browse;

  /// No description provided for @downloadUpdate.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get downloadUpdate;

  /// No description provided for @downloadNow.
  ///
  /// In zh, this message translates to:
  /// **'立即下载'**
  String get downloadNow;

  /// No description provided for @downloading.
  ///
  /// In zh, this message translates to:
  /// **'下载中'**
  String get downloading;

  /// No description provided for @downloadProgress.
  ///
  /// In zh, this message translates to:
  /// **'下载中 {p}%'**
  String downloadProgress(Object p);

  /// No description provided for @downloadComplete.
  ///
  /// In zh, this message translates to:
  /// **'下载完成'**
  String get downloadComplete;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载失败'**
  String get downloadFailed;

  /// No description provided for @installNow.
  ///
  /// In zh, this message translates to:
  /// **'立即安装'**
  String get installNow;

  /// No description provided for @installComplete.
  ///
  /// In zh, this message translates to:
  /// **'安装完成'**
  String get installComplete;

  /// No description provided for @openInstallDir.
  ///
  /// In zh, this message translates to:
  /// **'打开安装目录'**
  String get openInstallDir;

  /// No description provided for @deletePackage.
  ///
  /// In zh, this message translates to:
  /// **'删除安装包'**
  String get deletePackage;

  /// No description provided for @historyVersions.
  ///
  /// In zh, this message translates to:
  /// **'历史版本'**
  String get historyVersions;

  /// No description provided for @current.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get current;

  /// No description provided for @newVersion.
  ///
  /// In zh, this message translates to:
  /// **'新版本'**
  String get newVersion;

  /// No description provided for @latestVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get latestVersion;

  /// No description provided for @currentVersion.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus 当前版本'**
  String get currentVersion;

  /// No description provided for @checking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查新版本…'**
  String get checking;

  /// No description provided for @checkingGitCode.
  ///
  /// In zh, this message translates to:
  /// **'检查 GitCode 仓库'**
  String get checkingGitCode;

  /// No description provided for @updateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败'**
  String get updateFailed;

  /// No description provided for @noUpdateFound.
  ///
  /// In zh, this message translates to:
  /// **'当前已是最新版本'**
  String get noUpdateFound;

  /// No description provided for @newVersionFound.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get newVersionFound;

  /// No description provided for @downloadAgain.
  ///
  /// In zh, this message translates to:
  /// **'重新下载安装包'**
  String get downloadAgain;

  /// No description provided for @openDownloads.
  ///
  /// In zh, this message translates to:
  /// **'打开下载目录'**
  String get openDownloads;

  /// No description provided for @releaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get releaseNotes;

  /// No description provided for @currentVsRepo.
  ///
  /// In zh, this message translates to:
  /// **'本地 v{local} · 仓库最新 v{remote}'**
  String currentVsRepo(Object local, Object remote);

  /// No description provided for @installSize.
  ///
  /// In zh, this message translates to:
  /// **'{os} 安装包大小：{size}'**
  String installSize(Object os, Object size);

  /// No description provided for @alreadyDownloaded.
  ///
  /// In zh, this message translates to:
  /// **'安装包已下载'**
  String get alreadyDownloaded;

  /// No description provided for @downloadReady.
  ///
  /// In zh, this message translates to:
  /// **'下载一份安装包'**
  String get downloadReady;

  /// No description provided for @appInstallDir.
  ///
  /// In zh, this message translates to:
  /// **'安装目录'**
  String get appInstallDir;

  /// No description provided for @runInstaller.
  ///
  /// In zh, this message translates to:
  /// **'运行安装程序'**
  String get runInstaller;

  /// No description provided for @downloadUpdateTip.
  ///
  /// In zh, this message translates to:
  /// **'下载更新并自动打开'**
  String get downloadUpdateTip;

  /// No description provided for @openDownloadFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开下载目录'**
  String get openDownloadFolder;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
