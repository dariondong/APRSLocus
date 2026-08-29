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

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus'**
  String get appName;

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

  /// No description provided for @codeContributions.
  ///
  /// In zh, this message translates to:
  /// **'代码贡献'**
  String get codeContributions;

  /// No description provided for @codeContributionI18n.
  ///
  /// In zh, this message translates to:
  /// **'国际化 / 英文界面'**
  String get codeContributionI18n;

  /// No description provided for @licenseSection.
  ///
  /// In zh, this message translates to:
  /// **'许可证声明'**
  String get licenseSection;

  /// No description provided for @licenseName.
  ///
  /// In zh, this message translates to:
  /// **'GNU GPL v3'**
  String get licenseName;

  /// No description provided for @licenseStatement.
  ///
  /// In zh, this message translates to:
  /// **'本软件依据 GNU GPL v3 开源许可证发布。你可以在遵守许可证条款的前提下运行、研究、修改和再分发本软件；修改和再分发时须遵守 GPL v3 的相应义务。本软件不附带任何担保。'**
  String get licenseStatement;

  /// No description provided for @licenseText.
  ///
  /// In zh, this message translates to:
  /// **'查看许可证'**
  String get licenseText;

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

  /// No description provided for @groupBubble.
  ///
  /// In zh, this message translates to:
  /// **'群·{name}'**
  String groupBubble(String name);

  /// No description provided for @groupInviteTitle.
  ///
  /// In zh, this message translates to:
  /// **'群聊邀请'**
  String get groupInviteTitle;

  /// No description provided for @groupInviteFrom.
  ///
  /// In zh, this message translates to:
  /// **'{from} 邀请你加入群聊'**
  String groupInviteFrom(String from);

  /// No description provided for @groupNameValue.
  ///
  /// In zh, this message translates to:
  /// **'群名：{name}'**
  String groupNameValue(String name);

  /// No description provided for @groupCallsignValue.
  ///
  /// In zh, this message translates to:
  /// **'群呼号：{call}'**
  String groupCallsignValue(String call);

  /// No description provided for @groupInviteAccepted.
  ///
  /// In zh, this message translates to:
  /// **'已接受邀请，加入 {name}'**
  String groupInviteAccepted(String name);

  /// No description provided for @accept.
  ///
  /// In zh, this message translates to:
  /// **'接受'**
  String get accept;

  /// No description provided for @groupInviteRejected.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝 {name} 的邀请'**
  String groupInviteRejected(String name);

  /// No description provided for @reject.
  ///
  /// In zh, this message translates to:
  /// **'拒绝'**
  String get reject;

  /// No description provided for @appTagline.
  ///
  /// In zh, this message translates to:
  /// **'APRS 定位追踪'**
  String get appTagline;

  /// No description provided for @gridValue.
  ///
  /// In zh, this message translates to:
  /// **'网格 {grid}'**
  String gridValue(String grid);

  /// No description provided for @packetsPerMinute.
  ///
  /// In zh, this message translates to:
  /// **'{count}/分'**
  String packetsPerMinute(int count);

  /// No description provided for @demo.
  ///
  /// In zh, this message translates to:
  /// **'演示'**
  String get demo;

  /// No description provided for @nextBeaconIn.
  ///
  /// In zh, this message translates to:
  /// **'下次上报 {time}'**
  String nextBeaconIn(String time);

  /// No description provided for @beaconCount.
  ///
  /// In zh, this message translates to:
  /// **'信标 {count} 次'**
  String beaconCount(int count);

  /// No description provided for @beaconSentAprsIs.
  ///
  /// In zh, this message translates to:
  /// **'位置已上报 · 网格 {grid} · 已发往 APRS-IS'**
  String beaconSentAprsIs(String grid);

  /// No description provided for @beaconSentDemo.
  ///
  /// In zh, this message translates to:
  /// **'位置已上报 · 网格 {grid} · 演示'**
  String beaconSentDemo(String grid);

  /// No description provided for @getLocation.
  ///
  /// In zh, this message translates to:
  /// **'获取定位'**
  String get getLocation;

  /// No description provided for @disconnect.
  ///
  /// In zh, this message translates to:
  /// **'断开连接'**
  String get disconnect;

  /// No description provided for @connectAprsIs.
  ///
  /// In zh, this message translates to:
  /// **'连接 APRS-IS'**
  String get connectAprsIs;

  /// No description provided for @packetsReceived.
  ///
  /// In zh, this message translates to:
  /// **'收包'**
  String get packetsReceived;

  /// No description provided for @passcodeUnverified.
  ///
  /// In zh, this message translates to:
  /// **'Passcode 未验证'**
  String get passcodeUnverified;

  /// No description provided for @passcodeWarning.
  ///
  /// In zh, this message translates to:
  /// **'登录密码可能错误，无法正常收发消息'**
  String get passcodeWarning;

  /// No description provided for @goSettings.
  ///
  /// In zh, this message translates to:
  /// **'去设置'**
  String get goSettings;

  /// No description provided for @connectingServer.
  ///
  /// In zh, this message translates to:
  /// **'正在连接服务器…'**
  String get connectingServer;

  /// No description provided for @notConnectedAprsServer.
  ///
  /// In zh, this message translates to:
  /// **'未连接 APRS-IS 服务器'**
  String get notConnectedAprsServer;

  /// No description provided for @connectingToServer.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 {server}:{port}…'**
  String connectingToServer(String server, int port);

  /// No description provided for @connectNearbyDesc.
  ///
  /// In zh, this message translates to:
  /// **'连接后可接收附近台站定位与消息'**
  String get connectNearbyDesc;

  /// No description provided for @connectAction.
  ///
  /// In zh, this message translates to:
  /// **'连接'**
  String get connectAction;

  /// No description provided for @backgroundRunTip.
  ///
  /// In zh, this message translates to:
  /// **'后台运行提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。'**
  String get backgroundRunTip;

  /// No description provided for @connectedAprsIs.
  ///
  /// In zh, this message translates to:
  /// **'已连接 APRS-IS'**
  String get connectedAprsIs;

  /// No description provided for @qqGroupDesc.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus 软件 · 反馈问题/交流使用'**
  String get qqGroupDesc;

  /// No description provided for @reselectPoint.
  ///
  /// In zh, this message translates to:
  /// **'重新选点'**
  String get reselectPoint;

  /// No description provided for @disableClustering.
  ///
  /// In zh, this message translates to:
  /// **'关闭聚合'**
  String get disableClustering;

  /// No description provided for @enableClustering.
  ///
  /// In zh, this message translates to:
  /// **'开启聚合'**
  String get enableClustering;

  /// No description provided for @noPackets.
  ///
  /// In zh, this message translates to:
  /// **'暂无数据包'**
  String get noPackets;

  /// No description provided for @secondsAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}秒前'**
  String secondsAgo(int count);

  /// No description provided for @minutesAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}分前'**
  String minutesAgo(int count);

  /// No description provided for @hoursAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}小时前'**
  String hoursAgo(int count);

  /// No description provided for @daysAgo.
  ///
  /// In zh, this message translates to:
  /// **'{count}天前'**
  String daysAgo(int count);

  /// No description provided for @copiedCoordsValue.
  ///
  /// In zh, this message translates to:
  /// **'已复制坐标：{coords}'**
  String copiedCoordsValue(String coords);

  /// No description provided for @copiedGridValue.
  ///
  /// In zh, this message translates to:
  /// **'已复制网格：{grid}'**
  String copiedGridValue(String grid);

  /// No description provided for @distanceBearing.
  ///
  /// In zh, this message translates to:
  /// **'距我 {distance}km · 方位 {bearing}°'**
  String distanceBearing(String distance, String bearing);

  /// No description provided for @weatherDataValue.
  ///
  /// In zh, this message translates to:
  /// **'气象数据 · {data}'**
  String weatherDataValue(String data);

  /// No description provided for @symbolLabel.
  ///
  /// In zh, this message translates to:
  /// **'符号'**
  String get symbolLabel;

  /// No description provided for @digipeaterTapHint.
  ///
  /// In zh, this message translates to:
  /// **'点击中继台跳转到对应台站'**
  String get digipeaterTapHint;

  /// No description provided for @copiedFmoInfo.
  ///
  /// In zh, this message translates to:
  /// **'已复制 FMO 信息'**
  String get copiedFmoInfo;

  /// No description provided for @copiedAprslocusInfo.
  ///
  /// In zh, this message translates to:
  /// **'已复制 APRSlocus 信息'**
  String get copiedAprslocusInfo;

  /// No description provided for @trackPoints.
  ///
  /// In zh, this message translates to:
  /// **'轨迹 ({count} 点)'**
  String trackPoints(int count);

  /// No description provided for @sendMessageTo.
  ///
  /// In zh, this message translates to:
  /// **'发消息给 {call}…'**
  String sendMessageTo(String call);

  /// No description provided for @navigationUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'未安装高德地图，且无法打开其他地图应用'**
  String get navigationUnavailable;

  /// No description provided for @stationNoData.
  ///
  /// In zh, this message translates to:
  /// **'台站 {call} 尚未收到数据'**
  String stationNoData(String call);

  /// No description provided for @software.
  ///
  /// In zh, this message translates to:
  /// **'软件'**
  String get software;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @nameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get nameLabel;

  /// No description provided for @viewSponsorDetails.
  ///
  /// In zh, this message translates to:
  /// **'查看作者与赞助详情 →'**
  String get viewSponsorDetails;

  /// No description provided for @thanks.
  ///
  /// In zh, this message translates to:
  /// **'感谢'**
  String get thanks;

  /// No description provided for @qqSoftwareName.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus 软件'**
  String get qqSoftwareName;

  /// No description provided for @usageNotice.
  ///
  /// In zh, this message translates to:
  /// **'本软件仅供业余无线电爱好者学习交流使用\n请遵守当地无线电管理法规'**
  String get usageNotice;

  /// No description provided for @licenseNotice.
  ///
  /// In zh, this message translates to:
  /// **'GNU GPL v3 开源协议 · Copyright © BG7LZQ'**
  String get licenseNotice;

  /// No description provided for @appInfoText.
  ///
  /// In zh, this message translates to:
  /// **'APRSlocus v{version}\n作者: BG7LZQ (Darion)\n网站: Theez.top'**
  String appInfoText(String version);

  /// No description provided for @eggBg7lzq.
  ///
  /// In zh, this message translates to:
  /// **'哎呦你干嘛~'**
  String get eggBg7lzq;

  /// No description provided for @eggBg7pgw.
  ///
  /// In zh, this message translates to:
  /// **'闹呢？'**
  String get eggBg7pgw;

  /// No description provided for @eggBg7lmw.
  ///
  /// In zh, this message translates to:
  /// **'默不作声...'**
  String get eggBg7lmw;

  /// No description provided for @eggBg7osl.
  ///
  /// In zh, this message translates to:
  /// **'你的胆子肥嘟嘟的'**
  String get eggBg7osl;

  /// No description provided for @manualCallsignHint.
  ///
  /// In zh, this message translates to:
  /// **'手动输入呼号添加'**
  String get manualCallsignHint;

  /// No description provided for @noPacketReceived.
  ///
  /// In zh, this message translates to:
  /// **'未收到数据包'**
  String get noPacketReceived;

  /// No description provided for @feedMode.
  ///
  /// In zh, this message translates to:
  /// **'瀑布流'**
  String get feedMode;

  /// No description provided for @conversationMode.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conversationMode;

  /// No description provided for @messageFeed.
  ///
  /// In zh, this message translates to:
  /// **'消息瀑布流'**
  String get messageFeed;

  /// No description provided for @messageTotal.
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条'**
  String messageTotal(int count);

  /// No description provided for @noMessages.
  ///
  /// In zh, this message translates to:
  /// **'暂无消息'**
  String get noMessages;

  /// No description provided for @copiedClipboard.
  ///
  /// In zh, this message translates to:
  /// **'已复制到剪贴板'**
  String get copiedClipboard;

  /// No description provided for @groupShortLabel.
  ///
  /// In zh, this message translates to:
  /// **'群'**
  String get groupShortLabel;

  /// No description provided for @conversations.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get conversations;

  /// No description provided for @noConversations.
  ///
  /// In zh, this message translates to:
  /// **'暂无会话'**
  String get noConversations;

  /// No description provided for @groupNotFound.
  ///
  /// In zh, this message translates to:
  /// **'群聊不存在'**
  String get groupNotFound;

  /// No description provided for @invite.
  ///
  /// In zh, this message translates to:
  /// **'邀请'**
  String get invite;

  /// No description provided for @manage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get manage;

  /// No description provided for @noGroupMessages.
  ///
  /// In zh, this message translates to:
  /// **'群聊暂无消息'**
  String get noGroupMessages;

  /// No description provided for @selectConversation.
  ///
  /// In zh, this message translates to:
  /// **'选择会话开始聊天'**
  String get selectConversation;

  /// No description provided for @newConversation.
  ///
  /// In zh, this message translates to:
  /// **'新建会话'**
  String get newConversation;

  /// No description provided for @newConversationDesc.
  ///
  /// In zh, this message translates to:
  /// **'输入呼号开始新的会话'**
  String get newConversationDesc;

  /// No description provided for @callsignExample.
  ///
  /// In zh, this message translates to:
  /// **'呼号，如 BG7ABC'**
  String get callsignExample;

  /// No description provided for @start.
  ///
  /// In zh, this message translates to:
  /// **'开始'**
  String get start;

  /// No description provided for @broadcastMessage.
  ///
  /// In zh, this message translates to:
  /// **'群发消息'**
  String get broadcastMessage;

  /// No description provided for @noStations.
  ///
  /// In zh, this message translates to:
  /// **'暂无台站'**
  String get noStations;

  /// No description provided for @broadcastHint.
  ///
  /// In zh, this message translates to:
  /// **'提示：每条消息会单独发送给每个接收人'**
  String get broadcastHint;

  /// No description provided for @broadcastSent.
  ///
  /// In zh, this message translates to:
  /// **'已群发给 {count} 人'**
  String broadcastSent(int count);

  /// No description provided for @searchCallsign.
  ///
  /// In zh, this message translates to:
  /// **'搜索呼号…'**
  String get searchCallsign;

  /// No description provided for @broadcastContentHint.
  ///
  /// In zh, this message translates to:
  /// **'输入要群发的内容…'**
  String get broadcastContentHint;

  /// No description provided for @groupNameHint.
  ///
  /// In zh, this message translates to:
  /// **'输入群聊名称'**
  String get groupNameHint;

  /// No description provided for @create.
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// No description provided for @groupCallsignLine.
  ///
  /// In zh, this message translates to:
  /// **'群呼号: {call}'**
  String groupCallsignLine(String call);

  /// No description provided for @noMembers.
  ///
  /// In zh, this message translates to:
  /// **'暂无成员'**
  String get noMembers;

  /// No description provided for @inviteMembersHint.
  ///
  /// In zh, this message translates to:
  /// **'点击下方「邀请成员」添加'**
  String get inviteMembersHint;

  /// No description provided for @remove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get remove;

  /// No description provided for @inviteMembers.
  ///
  /// In zh, this message translates to:
  /// **'邀请成员'**
  String get inviteMembers;

  /// No description provided for @deleteGroup.
  ///
  /// In zh, this message translates to:
  /// **'删除群组'**
  String get deleteGroup;

  /// No description provided for @deleteGroupConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？此操作不可撤销。'**
  String deleteGroupConfirm(String name);

  /// No description provided for @memberOnlineCount.
  ///
  /// In zh, this message translates to:
  /// **'{members} 名成员 · {online} 在线'**
  String memberOnlineCount(int members, int online);

  /// No description provided for @leaveGroup.
  ///
  /// In zh, this message translates to:
  /// **'退出群组'**
  String get leaveGroup;

  /// No description provided for @leaveGroupConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定退出「{name}」？你将不再收到该群的消息。'**
  String leaveGroupConfirm(String name);

  /// No description provided for @leftGroup.
  ///
  /// In zh, this message translates to:
  /// **'已退出 {name}'**
  String leftGroup(String name);

  /// No description provided for @leave.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get leave;

  /// No description provided for @inviteMembersTo.
  ///
  /// In zh, this message translates to:
  /// **'邀请成员到 {name}'**
  String inviteMembersTo(String name);

  /// No description provided for @manualCallsign.
  ///
  /// In zh, this message translates to:
  /// **'手动输入呼号'**
  String get manualCallsign;

  /// No description provided for @inviteSent.
  ///
  /// In zh, this message translates to:
  /// **'已发送邀请给 {call}'**
  String inviteSent(String call);

  /// No description provided for @noMoreOnlineStations.
  ///
  /// In zh, this message translates to:
  /// **'暂无更多在线台站'**
  String get noMoreOnlineStations;

  /// No description provided for @invited.
  ///
  /// In zh, this message translates to:
  /// **'已邀请'**
  String get invited;

  /// No description provided for @tapToInvite.
  ///
  /// In zh, this message translates to:
  /// **'点击邀请'**
  String get tapToInvite;

  /// No description provided for @done.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get done;

  /// No description provided for @addContact.
  ///
  /// In zh, this message translates to:
  /// **'添加联系人'**
  String get addContact;

  /// No description provided for @addContactDesc.
  ///
  /// In zh, this message translates to:
  /// **'输入呼号手动添加到联系人列表'**
  String get addContactDesc;

  /// No description provided for @contactAdded.
  ///
  /// In zh, this message translates to:
  /// **'已添加联系人 {call}'**
  String contactAdded(String call);

  /// No description provided for @add.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get add;

  /// No description provided for @stationary.
  ///
  /// In zh, this message translates to:
  /// **'静止'**
  String get stationary;

  /// No description provided for @unknown.
  ///
  /// In zh, this message translates to:
  /// **'未知'**
  String get unknown;

  /// No description provided for @none.
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get none;

  /// No description provided for @manual.
  ///
  /// In zh, this message translates to:
  /// **'手动'**
  String get manual;

  /// No description provided for @management.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get management;

  /// No description provided for @debugLabel.
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get debugLabel;

  /// No description provided for @information.
  ///
  /// In zh, this message translates to:
  /// **'信息'**
  String get information;

  /// No description provided for @warning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get warning;

  /// No description provided for @errorLabel.
  ///
  /// In zh, this message translates to:
  /// **'错误'**
  String get errorLabel;

  /// No description provided for @countTimes.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次'**
  String countTimes(int count);

  /// No description provided for @countItems.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String countItems(int count);

  /// No description provided for @countEntries.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条'**
  String countEntries(int count);

  /// No description provided for @aprsSymbolName.
  ///
  /// In zh, this message translates to:
  /// **'{symbol, select, car {汽车} police {警局} person {人} digitalRepeater {数字中继} telephone {电话} dxCluster {DX 集群} hfGateway {HF 网关} smallAircraft {小型飞机} mobileSatellite {移动卫星} disabled {残障} snowmobile {雪地摩托} redCross {红十字} scouts {童子军} house {房屋} redX {红叉} redDot {红点} fire {火警} campground {露营} motorcycle {摩托} train {火车} fileServer {文件服务器} hurricane {飓风} dfTriangle {DF 三角} postOffice {邮局} largeAircraft {大型飞机} weatherStation {气象站} satelliteDish {卫星天线} ambulance {救护车} bicycle {自行车} commandPost {指挥中心} fireStation {消防站} horse {骑马} fireTruck {消防车} glider {滑翔机} hospital {医院} fmoStation {FMO 台站} jeep {吉普} truck {卡车} laptop {笔记本} micERepeater {Mic-E 中继} node {节点} emergencyOps {应急中心} dog {狗} gridSquare {网格} repeaterTower {中继塔} boat {船} truckStop {卡车停靠站} semiTrailer {半挂车} van {面包车} waterStation {供水站} yagi {八木天线屋} shelter {避难所} rv {房车} weatherSymbol {气象台} balloon {气球} bus {公交} shuttle {航天飞机} policeCar {警车} sailboat {帆船} school {学校} lodging {旅馆} hotel {酒店} other {未知}}'**
  String aprsSymbolName(String symbol);

  /// No description provided for @symbolCategoryName.
  ///
  /// In zh, this message translates to:
  /// **'{category, select, vehicles {车辆 / 交通} facilities {建筑 / 设施} weatherNature {气象 / 自然} emergencyRescue {应急救援} airWater {飞行 / 水域} communications {通信 / 其他} other {其他}}'**
  String symbolCategoryName(String category);

  /// No description provided for @countryName.
  ///
  /// In zh, this message translates to:
  /// **'{code, select, CN {中国} KR {韩国} JP {日本} US {美国} CA {加拿大} GB {英国} DE {德国} FR {法国} IT {意大利} ES {西班牙} RU {俄罗斯} AU {澳大利亚} NZ {新西兰} BR {巴西} AR {阿根廷} MX {墨西哥} ZA {南非} IN {印度} TH {泰国} SG {新加坡} MY {马来西亚} ID {印度尼西亚} PH {菲律宾} TW {台湾} HK {香港} MO {澳门} other {未知}}'**
  String countryName(String code);

  /// No description provided for @locationNotFixed.
  ///
  /// In zh, this message translates to:
  /// **'未定位'**
  String get locationNotFixed;

  /// No description provided for @simulatedLocation.
  ///
  /// In zh, this message translates to:
  /// **'模拟位置'**
  String get simulatedLocation;

  /// No description provided for @savedLocation.
  ///
  /// In zh, this message translates to:
  /// **'已保存位置'**
  String get savedLocation;

  /// No description provided for @locationFailed.
  ///
  /// In zh, this message translates to:
  /// **'定位失败'**
  String get locationFailed;

  /// No description provided for @locationStopped.
  ///
  /// In zh, this message translates to:
  /// **'定位已停止'**
  String get locationStopped;

  /// No description provided for @locationFixed.
  ///
  /// In zh, this message translates to:
  /// **'已定位'**
  String get locationFixed;

  /// No description provided for @locationPermission.
  ///
  /// In zh, this message translates to:
  /// **'请授予定位权限…'**
  String get locationPermission;

  /// No description provided for @gpsLocating.
  ///
  /// In zh, this message translates to:
  /// **'GPS 定位中…'**
  String get gpsLocating;

  /// No description provided for @webLocationUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'Web 平台暂不支持自动定位，请手动输入坐标'**
  String get webLocationUnsupported;

  /// No description provided for @locationStreamError.
  ///
  /// In zh, this message translates to:
  /// **'定位流异常：{error}'**
  String locationStreamError(String error);

  /// No description provided for @locationInitError.
  ///
  /// In zh, this message translates to:
  /// **'定位初始化失败：{error}'**
  String locationInitError(String error);

  /// No description provided for @beaconDisabled.
  ///
  /// In zh, this message translates to:
  /// **'已关闭'**
  String get beaconDisabled;

  /// No description provided for @waitingForLocation.
  ///
  /// In zh, this message translates to:
  /// **'等待定位'**
  String get waitingForLocation;

  /// No description provided for @imminent.
  ///
  /// In zh, this message translates to:
  /// **'即将'**
  String get imminent;

  /// No description provided for @connTapToConnect.
  ///
  /// In zh, this message translates to:
  /// **'未连接 · 点击播放按钮连接 APRS-IS'**
  String get connTapToConnect;

  /// No description provided for @connManuallyDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'未连接 · 已手动断开'**
  String get connManuallyDisconnected;

  /// No description provided for @connAutoReconnect.
  ///
  /// In zh, this message translates to:
  /// **'连接已断开 · {seconds}秒后自动重连…'**
  String connAutoReconnect(int seconds);

  /// No description provided for @connConnectingTarget.
  ///
  /// In zh, this message translates to:
  /// **'正在连接 {target}…'**
  String connConnectingTarget(String target);

  /// No description provided for @connOnline.
  ///
  /// In zh, this message translates to:
  /// **'已连接 · {call} 在线'**
  String connOnline(String call);

  /// No description provided for @connRetry.
  ///
  /// In zh, this message translates to:
  /// **'连接失败 · {seconds}s 后重试…'**
  String connRetry(int seconds);

  /// No description provided for @connPositionSent.
  ///
  /// In zh, this message translates to:
  /// **'已连接 · 位置已上报 ({call})'**
  String connPositionSent(String call);

  /// No description provided for @connDemoBeacon.
  ///
  /// In zh, this message translates to:
  /// **'未连接 · 位置已上报（模拟）'**
  String get connDemoBeacon;

  /// No description provided for @connPasscodeInvalid.
  ///
  /// In zh, this message translates to:
  /// **'已连接 · 未验证（Passcode 可能错误）'**
  String get connPasscodeInvalid;

  /// No description provided for @mapTypeAmap.
  ///
  /// In zh, this message translates to:
  /// **'高德地图'**
  String get mapTypeAmap;

  /// No description provided for @mapTypeAmapSatellite.
  ///
  /// In zh, this message translates to:
  /// **'高德卫星'**
  String get mapTypeAmapSatellite;

  /// No description provided for @mapTypeAmapJs.
  ///
  /// In zh, this message translates to:
  /// **'高德 JS'**
  String get mapTypeAmapJs;

  /// No description provided for @mapTypeVector.
  ///
  /// In zh, this message translates to:
  /// **'矢量地图'**
  String get mapTypeVector;

  /// No description provided for @amapGroup.
  ///
  /// In zh, this message translates to:
  /// **'高德'**
  String get amapGroup;

  /// No description provided for @domesticMaps.
  ///
  /// In zh, this message translates to:
  /// **'国内地图'**
  String get domesticMaps;

  /// No description provided for @internationalMaps.
  ///
  /// In zh, this message translates to:
  /// **'国际地图'**
  String get internationalMaps;

  /// No description provided for @metricUnits.
  ///
  /// In zh, this message translates to:
  /// **'公制 (km/h, m)'**
  String get metricUnits;

  /// No description provided for @coordDisplay.
  ///
  /// In zh, this message translates to:
  /// **'坐标显示'**
  String get coordDisplay;

  /// No description provided for @mapDefaultCoord.
  ///
  /// In zh, this message translates to:
  /// **'北京 · {level}级'**
  String mapDefaultCoord(int level);

  /// No description provided for @secondsValue.
  ///
  /// In zh, this message translates to:
  /// **'{count} 秒'**
  String secondsValue(int count);

  /// No description provided for @stationSettingsDetail.
  ///
  /// In zh, this message translates to:
  /// **'呼号、SSID、符号与备注'**
  String get stationSettingsDetail;

  /// No description provided for @stationIdentity.
  ///
  /// In zh, this message translates to:
  /// **'电台身份'**
  String get stationIdentity;

  /// No description provided for @aprsCallsignHint.
  ///
  /// In zh, this message translates to:
  /// **'APRS 呼号，如 BV2AAA'**
  String get aprsCallsignHint;

  /// No description provided for @displayInfo.
  ///
  /// In zh, this message translates to:
  /// **'显示信息'**
  String get displayInfo;

  /// No description provided for @ssidSuffix.
  ///
  /// In zh, this message translates to:
  /// **'SSID 后缀'**
  String get ssidSuffix;

  /// No description provided for @chooseSsidSuffix.
  ///
  /// In zh, this message translates to:
  /// **'选择 SSID 后缀'**
  String get chooseSsidSuffix;

  /// No description provided for @mySymbol.
  ///
  /// In zh, this message translates to:
  /// **'我的符号'**
  String get mySymbol;

  /// No description provided for @moreSymbols.
  ///
  /// In zh, this message translates to:
  /// **'更多符号'**
  String get moreSymbols;

  /// No description provided for @allAprsSymbols.
  ///
  /// In zh, this message translates to:
  /// **'全部 APRS 符号'**
  String get allAprsSymbols;

  /// No description provided for @beaconSettingsDetail.
  ///
  /// In zh, this message translates to:
  /// **'GPS 来源、信标与手动定位'**
  String get beaconSettingsDetail;

  /// No description provided for @locationSource.
  ///
  /// In zh, this message translates to:
  /// **'定位来源'**
  String get locationSource;

  /// No description provided for @useDeviceLocation.
  ///
  /// In zh, this message translates to:
  /// **'使用设备定位'**
  String get useDeviceLocation;

  /// No description provided for @manualCoordinates.
  ///
  /// In zh, this message translates to:
  /// **'手动输入坐标'**
  String get manualCoordinates;

  /// No description provided for @beaconingSection.
  ///
  /// In zh, this message translates to:
  /// **'信标上报'**
  String get beaconingSection;

  /// No description provided for @beaconIntervalTip.
  ///
  /// In zh, this message translates to:
  /// **'位置信标的发送间隔，至少 5 秒'**
  String get beaconIntervalTip;

  /// No description provided for @beaconContent.
  ///
  /// In zh, this message translates to:
  /// **'信标上报内容'**
  String get beaconContent;

  /// No description provided for @beaconContentDesc.
  ///
  /// In zh, this message translates to:
  /// **'随位置信标一起发送'**
  String get beaconContentDesc;

  /// No description provided for @phoneBattery.
  ///
  /// In zh, this message translates to:
  /// **'手机电量'**
  String get phoneBattery;

  /// No description provided for @locationStatus.
  ///
  /// In zh, this message translates to:
  /// **'定位状态'**
  String get locationStatus;

  /// No description provided for @relocate.
  ///
  /// In zh, this message translates to:
  /// **'重新定位'**
  String get relocate;

  /// No description provided for @startGps.
  ///
  /// In zh, this message translates to:
  /// **'开启 GPS 定位'**
  String get startGps;

  /// No description provided for @trackingBeaconing.
  ///
  /// In zh, this message translates to:
  /// **'定位运行中，正在持续上报位置'**
  String get trackingBeaconing;

  /// No description provided for @manualLocation.
  ///
  /// In zh, this message translates to:
  /// **'手动定位'**
  String get manualLocation;

  /// No description provided for @latitudeHint.
  ///
  /// In zh, this message translates to:
  /// **'纬度 39.9042'**
  String get latitudeHint;

  /// No description provided for @longitudeHint.
  ///
  /// In zh, this message translates to:
  /// **'经度 116.4074'**
  String get longitudeHint;

  /// No description provided for @invalidLatLng.
  ///
  /// In zh, this message translates to:
  /// **'请输入有效经纬度'**
  String get invalidLatLng;

  /// No description provided for @myLocationSetGrid.
  ///
  /// In zh, this message translates to:
  /// **'已设置我的位置，网格 {grid}'**
  String myLocationSetGrid(String grid);

  /// No description provided for @applyCoordinates.
  ///
  /// In zh, this message translates to:
  /// **'应用坐标'**
  String get applyCoordinates;

  /// No description provided for @pickOnMap.
  ///
  /// In zh, this message translates to:
  /// **'在地图选点'**
  String get pickOnMap;

  /// No description provided for @manualLocationHelp.
  ///
  /// In zh, this message translates to:
  /// **'无法自动定位时，可手动输入经纬度或用地图选点，用于信标上报与台站距离计算。'**
  String get manualLocationHelp;

  /// No description provided for @passcodeTip.
  ///
  /// In zh, this message translates to:
  /// **'APRS-IS 登录验证码，可在线生成；填 -1 表示未验证'**
  String get passcodeTip;

  /// No description provided for @websocketOptional.
  ///
  /// In zh, this message translates to:
  /// **'WebSocket URL（可选）'**
  String get websocketOptional;

  /// No description provided for @configChanged.
  ///
  /// In zh, this message translates to:
  /// **'配置已修改'**
  String get configChanged;

  /// No description provided for @reconnectToApply.
  ///
  /// In zh, this message translates to:
  /// **'重新连接后生效'**
  String get reconnectToApply;

  /// No description provided for @reconnected.
  ///
  /// In zh, this message translates to:
  /// **'已重新连接'**
  String get reconnected;

  /// No description provided for @connectFailedCheckConfig.
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查配置'**
  String get connectFailedCheckConfig;

  /// No description provided for @rangeFilterDesc.
  ///
  /// In zh, this message translates to:
  /// **'只接收设定范围内的台站数据包'**
  String get rangeFilterDesc;

  /// No description provided for @filterCenterFollows.
  ///
  /// In zh, this message translates to:
  /// **'过滤中心跟随我的位置'**
  String get filterCenterFollows;

  /// No description provided for @radiusTip.
  ///
  /// In zh, this message translates to:
  /// **'接收半径（km），点“保存并应用”生效'**
  String get radiusTip;

  /// No description provided for @maxStationsTip.
  ///
  /// In zh, this message translates to:
  /// **'内存中保留的最大台站数量（默认不限制，可设更大值）'**
  String get maxStationsTip;

  /// No description provided for @filterSavedRadius.
  ///
  /// In zh, this message translates to:
  /// **'{saved} · 半径 {radius}km'**
  String filterSavedRadius(String saved, int radius);

  /// No description provided for @receiveFilterDesc2.
  ///
  /// In zh, this message translates to:
  /// **'除范围过滤外，按国家/地区分组或精确呼号接收台站'**
  String get receiveFilterDesc2;

  /// No description provided for @receiveCountryDesc.
  ///
  /// In zh, this message translates to:
  /// **'按呼号前缀批量接收某国家/地区全部台站'**
  String get receiveCountryDesc;

  /// No description provided for @noCountriesSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择国家/地区'**
  String get noCountriesSelected;

  /// No description provided for @receiveOthersDesc.
  ///
  /// In zh, this message translates to:
  /// **'接收不匹配所选国家的特殊呼号台站'**
  String get receiveOthersDesc;

  /// No description provided for @addCountry.
  ///
  /// In zh, this message translates to:
  /// **'添加国家/地区'**
  String get addCountry;

  /// No description provided for @chatSettingsDetail.
  ///
  /// In zh, this message translates to:
  /// **'消息、联系人与聊天数据'**
  String get chatSettingsDetail;

  /// No description provided for @messageCountLabel.
  ///
  /// In zh, this message translates to:
  /// **'消息条数'**
  String get messageCountLabel;

  /// No description provided for @manageContacts.
  ///
  /// In zh, this message translates to:
  /// **'管理联系人'**
  String get manageContacts;

  /// No description provided for @deleteAllChatsConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要删除全部 {count} 条聊天记录吗？此操作不可恢复。'**
  String deleteAllChatsConfirm(int count);

  /// No description provided for @chatCleared.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录已清空'**
  String get chatCleared;

  /// No description provided for @noContacts.
  ///
  /// In zh, this message translates to:
  /// **'暂无联系人'**
  String get noContacts;

  /// No description provided for @addOrFavoriteContact.
  ///
  /// In zh, this message translates to:
  /// **'点击右上角“添加”或在地图上收藏台站'**
  String get addOrFavoriteContact;

  /// No description provided for @movingWithSpeed.
  ///
  /// In zh, this message translates to:
  /// **'移动中 · {speed}'**
  String movingWithSpeed(String speed);

  /// No description provided for @callsignMin3.
  ///
  /// In zh, this message translates to:
  /// **'呼号至少 3 个字符'**
  String get callsignMin3;

  /// No description provided for @deleteContact.
  ///
  /// In zh, this message translates to:
  /// **'删除联系人'**
  String get deleteContact;

  /// No description provided for @deleteContactConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除联系人 {call}？'**
  String deleteContactConfirm(String call);

  /// No description provided for @contactDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除 {call}'**
  String contactDeleted(String call);

  /// No description provided for @dataMaintenance.
  ///
  /// In zh, this message translates to:
  /// **'数据维护'**
  String get dataMaintenance;

  /// No description provided for @clearAllData.
  ///
  /// In zh, this message translates to:
  /// **'清除所有数据'**
  String get clearAllData;

  /// No description provided for @clearAllDataIntro.
  ///
  /// In zh, this message translates to:
  /// **'此操作将删除以下所有本地数据：'**
  String get clearAllDataIntro;

  /// No description provided for @chatHistory.
  ///
  /// In zh, this message translates to:
  /// **'聊天记录'**
  String get chatHistory;

  /// No description provided for @logs.
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get logs;

  /// No description provided for @irreversibleKeepSettings.
  ///
  /// In zh, this message translates to:
  /// **'此操作不可恢复，连接设置和呼号不会被删除。'**
  String get irreversibleKeepSettings;

  /// No description provided for @confirmClearAllData.
  ///
  /// In zh, this message translates to:
  /// **'确认清除所有数据'**
  String get confirmClearAllData;

  /// No description provided for @clearAllDataConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定要清除全部本地数据吗？此操作不可恢复。'**
  String get clearAllDataConfirm;

  /// No description provided for @allDataCleared.
  ///
  /// In zh, this message translates to:
  /// **'所有数据已清除'**
  String get allDataCleared;

  /// No description provided for @confirmClear.
  ///
  /// In zh, this message translates to:
  /// **'确认清除'**
  String get confirmClear;

  /// No description provided for @allowLandscape.
  ///
  /// In zh, this message translates to:
  /// **'允许手机横屏显示'**
  String get allowLandscape;

  /// No description provided for @packetParseTest.
  ///
  /// In zh, this message translates to:
  /// **'数据包解析测试'**
  String get packetParseTest;

  /// No description provided for @packetParseHint.
  ///
  /// In zh, this message translates to:
  /// **'粘贴原始 APRS 包，如：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test station'**
  String get packetParseHint;

  /// No description provided for @parseAndApply.
  ///
  /// In zh, this message translates to:
  /// **'解析并应用'**
  String get parseAndApply;

  /// No description provided for @oobePasscodeMissing.
  ///
  /// In zh, this message translates to:
  /// **'Passcode 未填写'**
  String get oobePasscodeMissing;

  /// No description provided for @oobePasscodeMissingDesc.
  ///
  /// In zh, this message translates to:
  /// **'Passcode 是 APRS-IS 登录验证码，用于识别你的呼号。\n\n使用默认值 -1（未验证）虽然可以连接，但将无法正常收发消息与群聊。\n\n建议在 https://aprs.cool/AprsPG 输入呼号查询正确 Passcode 后填写。'**
  String get oobePasscodeMissingDesc;

  /// No description provided for @continueAnyway.
  ///
  /// In zh, this message translates to:
  /// **'仍然继续'**
  String get continueAnyway;

  /// No description provided for @fillPasscode.
  ///
  /// In zh, this message translates to:
  /// **'去填写'**
  String get fillPasscode;

  /// No description provided for @oobeMapFeatureDesc.
  ///
  /// In zh, this message translates to:
  /// **'高德地图瓦片，查看附近 APRS 台站与轨迹'**
  String get oobeMapFeatureDesc;

  /// No description provided for @oobeGpsFeatureDesc.
  ///
  /// In zh, this message translates to:
  /// **'自动获取位置并发送信标到 APRS-IS'**
  String get oobeGpsFeatureDesc;

  /// No description provided for @oobeMsgFeatureDesc.
  ///
  /// In zh, this message translates to:
  /// **'与台站收发消息，支持自动应答'**
  String get oobeMsgFeatureDesc;

  /// No description provided for @oobeIsFeatureDesc.
  ///
  /// In zh, this message translates to:
  /// **'连接公共服务器，接收全球台站数据'**
  String get oobeIsFeatureDesc;

  /// No description provided for @oobeBackgroundTip.
  ///
  /// In zh, this message translates to:
  /// **'提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。'**
  String get oobeBackgroundTip;

  /// No description provided for @oobeNextSteps.
  ///
  /// In zh, this message translates to:
  /// **'接下来几步完成基础配置，随时可在设置中修改。'**
  String get oobeNextSteps;

  /// No description provided for @ssidDescShort.
  ///
  /// In zh, this message translates to:
  /// **'SSID 是呼号后面的数字标识，如 BG7ABC-9 中的 -9'**
  String get ssidDescShort;

  /// No description provided for @ssidOptional.
  ///
  /// In zh, this message translates to:
  /// **'SSID 后缀（可选）'**
  String get ssidOptional;

  /// No description provided for @noSsid.
  ///
  /// In zh, this message translates to:
  /// **'无后缀（基本呼号）'**
  String get noSsid;

  /// No description provided for @fullCallsign.
  ///
  /// In zh, this message translates to:
  /// **'完整呼号：{call}'**
  String fullCallsign(String call);

  /// No description provided for @passcodeImportant.
  ///
  /// In zh, this message translates to:
  /// **'Passcode 非常重要'**
  String get passcodeImportant;

  /// No description provided for @passcodeImportantDesc.
  ///
  /// In zh, this message translates to:
  /// **'正确的 Passcode 是接收群聊消息和发送确认消息的前提。填 -1 虽然可以连接，但无法正常收发消息。'**
  String get passcodeImportantDesc;

  /// No description provided for @lookupPasscode.
  ///
  /// In zh, this message translates to:
  /// **'点击查询你的 Passcode →'**
  String get lookupPasscode;

  /// No description provided for @passcodeLookupHint.
  ///
  /// In zh, this message translates to:
  /// **'输入你的呼号即可获取，例如 BV2AAA'**
  String get passcodeLookupHint;

  /// No description provided for @sendToGroupHint.
  ///
  /// In zh, this message translates to:
  /// **'发到 {group}…'**
  String sendToGroupHint(String group);

  /// No description provided for @sendToCallHint.
  ///
  /// In zh, this message translates to:
  /// **'发给 {call}…'**
  String sendToCallHint(String call);

  /// No description provided for @selectMessageReply.
  ///
  /// In zh, this message translates to:
  /// **'点选消息以回复…'**
  String get selectMessageReply;

  /// No description provided for @broadcastShort.
  ///
  /// In zh, this message translates to:
  /// **'群发'**
  String get broadcastShort;

  /// No description provided for @memberCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个成员'**
  String memberCount(int count);

  /// No description provided for @memberCountTap.
  ///
  /// In zh, this message translates to:
  /// **'{count} 名成员 · 点击查看'**
  String memberCountTap(int count);

  /// No description provided for @stepRecipients.
  ///
  /// In zh, this message translates to:
  /// **'选人'**
  String get stepRecipients;

  /// No description provided for @stepContent.
  ///
  /// In zh, this message translates to:
  /// **'内容'**
  String get stepContent;

  /// No description provided for @selectAllOnline.
  ///
  /// In zh, this message translates to:
  /// **'全选在线'**
  String get selectAllOnline;

  /// No description provided for @clearSelection.
  ///
  /// In zh, this message translates to:
  /// **'取消全选'**
  String get clearSelection;

  /// No description provided for @onlineOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅在线'**
  String get onlineOnly;

  /// No description provided for @noRecipients.
  ///
  /// In zh, this message translates to:
  /// **'未选择接收人'**
  String get noRecipients;

  /// No description provided for @selectedRecipients.
  ///
  /// In zh, this message translates to:
  /// **'已选 {count} 人'**
  String selectedRecipients(int count);

  /// No description provided for @sendRecipientsList.
  ///
  /// In zh, this message translates to:
  /// **'将发送给 {count} 人：{calls}'**
  String sendRecipientsList(int count, String calls);

  /// No description provided for @stepName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get stepName;

  /// No description provided for @stepMembers.
  ///
  /// In zh, this message translates to:
  /// **'成员'**
  String get stepMembers;

  /// No description provided for @groupChatExplain.
  ///
  /// In zh, this message translates to:
  /// **'群聊使用群呼号广播消息，所有成员都能收到。创建后系统会自动生成群呼号并邀请你选择的成员。'**
  String get groupChatExplain;

  /// No description provided for @noMembersSelected.
  ///
  /// In zh, this message translates to:
  /// **'未选择成员'**
  String get noMembersSelected;

  /// No description provided for @memberBlocked.
  ///
  /// In zh, this message translates to:
  /// **'已屏蔽'**
  String get memberBlocked;

  /// No description provided for @memberJoined.
  ///
  /// In zh, this message translates to:
  /// **'已加入'**
  String get memberJoined;

  /// No description provided for @memberPending.
  ///
  /// In zh, this message translates to:
  /// **'待确认'**
  String get memberPending;

  /// No description provided for @memberDeclined.
  ///
  /// In zh, this message translates to:
  /// **'已拒绝'**
  String get memberDeclined;

  /// No description provided for @memberLeft.
  ///
  /// In zh, this message translates to:
  /// **'已退出'**
  String get memberLeft;

  /// No description provided for @memberTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时'**
  String get memberTimeout;

  /// No description provided for @unblock.
  ///
  /// In zh, this message translates to:
  /// **'解除屏蔽'**
  String get unblock;

  /// No description provided for @block.
  ///
  /// In zh, this message translates to:
  /// **'屏蔽'**
  String get block;

  /// No description provided for @groupOwner.
  ///
  /// In zh, this message translates to:
  /// **'群主'**
  String get groupOwner;

  /// No description provided for @systemMemberJoined.
  ///
  /// In zh, this message translates to:
  /// **'{call} 加入了群聊'**
  String systemMemberJoined(String call);

  /// No description provided for @systemMemberLeft.
  ///
  /// In zh, this message translates to:
  /// **'{call} 离开了群聊'**
  String systemMemberLeft(String call);

  /// No description provided for @systemInviteDeclined.
  ///
  /// In zh, this message translates to:
  /// **'{call} 拒绝了邀请'**
  String systemInviteDeclined(String call);

  /// No description provided for @copyAllLogs.
  ///
  /// In zh, this message translates to:
  /// **'复制全部日志'**
  String get copyAllLogs;

  /// No description provided for @copiedLogs.
  ///
  /// In zh, this message translates to:
  /// **'已复制 {count} 条日志'**
  String copiedLogs(int count);

  /// No description provided for @clearLogs.
  ///
  /// In zh, this message translates to:
  /// **'清空日志'**
  String get clearLogs;

  /// No description provided for @noLogs.
  ///
  /// In zh, this message translates to:
  /// **'暂无日志'**
  String get noLogs;

  /// No description provided for @supportProject.
  ///
  /// In zh, this message translates to:
  /// **'你们的支持让项目走得更远'**
  String get supportProject;

  /// No description provided for @continuousIteration.
  ///
  /// In zh, this message translates to:
  /// **'持续迭代'**
  String get continuousIteration;

  /// No description provided for @continuousIterationDesc.
  ///
  /// In zh, this message translates to:
  /// **'不断改进 APRSlocus 功能与体验'**
  String get continuousIterationDesc;

  /// No description provided for @sponsorSupport.
  ///
  /// In zh, this message translates to:
  /// **'赞助支持'**
  String get sponsorSupport;

  /// No description provided for @sponsorMethods.
  ///
  /// In zh, this message translates to:
  /// **'赞助方式'**
  String get sponsorMethods;

  /// No description provided for @qrCodeTitle.
  ///
  /// In zh, this message translates to:
  /// **'{title} 赞赏码'**
  String qrCodeTitle(String title);

  /// No description provided for @qrLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'赞赏码图片加载失败'**
  String get qrLoadFailed;

  /// No description provided for @qrSaveWechat.
  ///
  /// In zh, this message translates to:
  /// **'长按图片可保存 · 微信扫一扫赞赏'**
  String get qrSaveWechat;

  /// No description provided for @tapAnywhereClose.
  ///
  /// In zh, this message translates to:
  /// **'点击任意处关闭'**
  String get tapAnywhereClose;

  /// No description provided for @webAmapUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'Web 平台暂不支持高德 JS 地图'**
  String get webAmapUnsupported;

  /// No description provided for @webview2InitFailed.
  ///
  /// In zh, this message translates to:
  /// **'WebView2 初始化失败\n请安装 Microsoft Edge WebView2 运行时'**
  String get webview2InitFailed;

  /// No description provided for @loadingAmap.
  ///
  /// In zh, this message translates to:
  /// **'加载高德地图…'**
  String get loadingAmap;

  /// No description provided for @vectorMapLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'矢量地图加载失败\n{error}'**
  String vectorMapLoadFailed(String error);

  /// No description provided for @loadingVectorMap.
  ///
  /// In zh, this message translates to:
  /// **'加载矢量地图…'**
  String get loadingVectorMap;

  /// No description provided for @updateChannel.
  ///
  /// In zh, this message translates to:
  /// **'更新渠道'**
  String get updateChannel;

  /// No description provided for @serverReturned.
  ///
  /// In zh, this message translates to:
  /// **'服务器返回 {code}'**
  String serverReturned(int code);

  /// No description provided for @invalidResponseData.
  ///
  /// In zh, this message translates to:
  /// **'返回数据格式错误'**
  String get invalidResponseData;

  /// No description provided for @noVersionsFound.
  ///
  /// In zh, this message translates to:
  /// **'没有找到任何版本'**
  String get noVersionsFound;

  /// No description provided for @noWindowsInstaller.
  ///
  /// In zh, this message translates to:
  /// **'该版本没有 Windows 安装包'**
  String get noWindowsInstaller;

  /// No description provided for @noApkInstaller.
  ///
  /// In zh, this message translates to:
  /// **'该版本没有 APK 安装包'**
  String get noApkInstaller;

  /// No description provided for @connectingEllipsis.
  ///
  /// In zh, this message translates to:
  /// **'正在连接…'**
  String get connectingEllipsis;

  /// No description provided for @downloadHttpError.
  ///
  /// In zh, this message translates to:
  /// **'下载失败：HTTP {code}'**
  String downloadHttpError(int code);

  /// No description provided for @downloadedBytes.
  ///
  /// In zh, this message translates to:
  /// **'已下载 {received} / {total}'**
  String downloadedBytes(String received, String total);

  /// No description provided for @androidInstallHelp.
  ///
  /// In zh, this message translates to:
  /// **'安装包已下载到：\n{path}\n\n点击“安装”后，系统会弹出安装确认框。\n\n若提示“不允许安装未知来源应用”，请到系统设置中允许本应用安装未知应用。'**
  String androidInstallHelp(String path);

  /// No description provided for @windowsInstallHelp.
  ///
  /// In zh, this message translates to:
  /// **'安装包已保存到：\n{path}\n\n点击“立即运行”直接启动安装程序；也可以打开所在目录查看文件。'**
  String windowsInstallHelp(String path);

  /// No description provided for @openContainingFolder.
  ///
  /// In zh, this message translates to:
  /// **'打开所在目录'**
  String get openContainingFolder;

  /// No description provided for @runNow.
  ///
  /// In zh, this message translates to:
  /// **'立即运行'**
  String get runNow;

  /// No description provided for @cannotRunInstaller.
  ///
  /// In zh, this message translates to:
  /// **'无法启动安装程序，请到所在目录手动打开'**
  String get cannotRunInstaller;

  /// No description provided for @cannotLaunchInstaller.
  ///
  /// In zh, this message translates to:
  /// **'无法启动安装器，请手动打开安装包'**
  String get cannotLaunchInstaller;

  /// No description provided for @openPackageManually.
  ///
  /// In zh, this message translates to:
  /// **'请在文件管理器中打开安装包'**
  String get openPackageManually;

  /// No description provided for @cannotOpenPackage.
  ///
  /// In zh, this message translates to:
  /// **'无法打开安装包：{error}'**
  String cannotOpenPackage(String error);

  /// No description provided for @installPermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要允许安装应用'**
  String get installPermissionTitle;

  /// No description provided for @installPermissionDesc.
  ///
  /// In zh, this message translates to:
  /// **'检测到系统未允许 APRSlocus 安装应用。\n\n请点击“去设置”，在“安装未知应用”中允许本应用安装应用，然后返回重新安装。'**
  String get installPermissionDesc;

  /// No description provided for @recheck.
  ///
  /// In zh, this message translates to:
  /// **'重新检查'**
  String get recheck;

  /// No description provided for @signatureChangedTitle.
  ///
  /// In zh, this message translates to:
  /// **'签名已更换 · 需卸载重装'**
  String get signatureChangedTitle;

  /// No description provided for @signatureChangedDesc.
  ///
  /// In zh, this message translates to:
  /// **'本次更新更换了正式签名（1.4.8 起）。旧版本无法直接覆盖安装，请先卸载手机上的 APRSlocus 再安装新版，否则会提示签名冲突。'**
  String get signatureChangedDesc;

  /// No description provided for @newVersionTitle.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 v{version}'**
  String newVersionTitle(String version);

  /// No description provided for @repoLatestTitle.
  ///
  /// In zh, this message translates to:
  /// **'仓库最新版本 v{version}'**
  String repoLatestTitle(String version);

  /// No description provided for @checkingLatest.
  ///
  /// In zh, this message translates to:
  /// **'正在检查最新版本…'**
  String get checkingLatest;

  /// No description provided for @connectingGitCode.
  ///
  /// In zh, this message translates to:
  /// **'连接 GitCode 服务器'**
  String get connectingGitCode;

  /// No description provided for @noReleaseNotes.
  ///
  /// In zh, this message translates to:
  /// **'暂无更新说明'**
  String get noReleaseNotes;

  /// No description provided for @noInstallerHistoryHint.
  ///
  /// In zh, this message translates to:
  /// **'该版本暂无 {platform} 安装包，请到历史版本中选择可下载的版本'**
  String noInstallerHistoryHint(String platform);

  /// No description provided for @latestVersionLabel.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get latestVersionLabel;

  /// No description provided for @packageSize.
  ///
  /// In zh, this message translates to:
  /// **'{platform} 安装包大小：{size}'**
  String packageSize(String platform, String size);

  /// No description provided for @updateContents.
  ///
  /// In zh, this message translates to:
  /// **'更新内容'**
  String get updateContents;

  /// No description provided for @redownload.
  ///
  /// In zh, this message translates to:
  /// **'重新下载'**
  String get redownload;

  /// No description provided for @downloadInstaller.
  ///
  /// In zh, this message translates to:
  /// **'下载安装包'**
  String get downloadInstaller;

  /// No description provided for @downloadAndInstall.
  ///
  /// In zh, this message translates to:
  /// **'下载并安装'**
  String get downloadAndInstall;

  /// No description provided for @localPackageExists.
  ///
  /// In zh, this message translates to:
  /// **'本地已有一份安装包'**
  String get localPackageExists;

  /// No description provided for @packageDeleted.
  ///
  /// In zh, this message translates to:
  /// **'安装包已删除'**
  String get packageDeleted;

  /// No description provided for @versionCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个'**
  String versionCount(int count);

  /// No description provided for @noInstaller.
  ///
  /// In zh, this message translates to:
  /// **'无安装包'**
  String get noInstaller;

  /// No description provided for @download.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// No description provided for @viewChangelog.
  ///
  /// In zh, this message translates to:
  /// **'查看更新日志'**
  String get viewChangelog;

  /// No description provided for @versionChangelog.
  ///
  /// In zh, this message translates to:
  /// **'v{version} 更新日志'**
  String versionChangelog(String version);

  /// No description provided for @gotIt.
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get gotIt;

  /// No description provided for @leaveAction.
  ///
  /// In zh, this message translates to:
  /// **'退出'**
  String get leaveAction;

  /// No description provided for @localRepoVersion.
  ///
  /// In zh, this message translates to:
  /// **'本地 v{local} · 仓库最新 v{latest}'**
  String localRepoVersion(Object latest, Object local);

  /// No description provided for @unverified.
  ///
  /// In zh, this message translates to:
  /// **'未验证'**
  String get unverified;

  /// No description provided for @passcodeUnverifiedHint.
  ///
  /// In zh, this message translates to:
  /// **'-1 未验证'**
  String get passcodeUnverifiedHint;

  /// No description provided for @passcodeMessageWarning.
  ///
  /// In zh, this message translates to:
  /// **'APRS-IS 登录验证码，填 -1 无法正常收发消息'**
  String get passcodeMessageWarning;
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
