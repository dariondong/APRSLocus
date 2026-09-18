import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'widgets.dart' show S;
import 'theme_store.dart';

/// ─── 可被主题覆写的文案取值口 ───
///
/// 为什么要有这一层，而不是直接改 `S.of(context).map`：
///
/// l10n 的值是 gen-l10n 生成的 getter，**编译期定死**，运行时无法改写。
/// 所以要支持「用户自定义文字」，必须有一个中间层：先问主题有没有覆写，
/// 没有再回退到 l10n。
///
/// 为什么不把全部 1662 条文案都开放覆写：按钮动词（确定/取消/删除）与
/// 错误提示是用户的**操作依据**，被改成不认识的词会让应用变得不可操作。
/// 所以只开放 [kThemeTextKeys] 里那批高频、且改坏了也不影响可操作性的文案。
///
/// 用法：把想开放自定义的那几十处从 `S.of(context).map` 换成 `Tx.of(context).navMap`。
/// 没有主题覆写时两者完全等价 —— 没装主题的界面一个像素都不会变。
class Tx {
  final AppLocalizations s;

  const Tx(this.s);

  static Tx of(BuildContext context) => Tx(S.of(context));

  String _o(String key, String fallback) =>
      ThemeController.instance.textFor(key) ?? fallback;

  // ─── 底部页签 ───
  String get navMap => _o('map', s.map);
  String get navStations => _o('stations', s.stations);
  String get navMessages => _o('messages', s.messages);
  String get navPackets => _o('packets', s.packets);
  String get navSettings => _o('settings', s.settings);

  /// 按 l10n 键取（编辑页预览用；键必须已在 [kThemeTextKeys] 白名单内）
  String byKey(String key) {
    switch (key) {
      case 'map':
        return navMap;
      case 'stations':
        return navStations;
      case 'messages':
        return navMessages;
      case 'packets':
        return navPackets;
      case 'settings':
        return navSettings;
      case 'radioCat':
        return _o(key, s.radioCat);
      case 'radioCatDesc':
        return _o(key, s.radioCatDesc);
      case 'beaconCat':
        return _o(key, s.beaconCat);
      case 'beaconCatDesc':
        return _o(key, s.beaconCatDesc);
      case 'connectionCat':
        return _o(key, s.connectionCat);
      case 'connectionCatDesc':
        return _o(key, s.connectionCatDesc);
      case 'displayCat':
        return _o(key, s.displayCat);
      case 'displayCatDesc':
        return _o(key, s.displayCatDesc);
      case 'deviceCat':
        return _o(key, s.deviceCat);
      case 'deviceCatDesc':
        return _o(key, s.deviceCatDesc);
      case 'dataCat':
        return _o(key, s.dataCat);
      case 'dataCatDesc':
        return _o(key, s.dataCatDesc);
      case 'advancedCat':
        return _o(key, s.advancedCat);
      case 'advancedCatDesc':
        return _o(key, s.advancedCatDesc);
      case 'updateCat':
        return _o(key, s.updateCat);
      case 'updateCatDesc':
        return _o(key, s.updateCatDesc);
      case 'honorWall':
        return _o(key, s.honorWall);
      case 'translateSettings':
        return _o(key, s.translateSettings);
      case 'exportAdif':
        return _o(key, s.exportAdif);
      case 'backupTitle':
        return _o(key, s.backupTitle);
      case 'about':
        return _o(key, s.about);
    }
    // 白名单之外的键一律忽略（与导入时的校验保持同一套规则）
    return key;
  }
}
