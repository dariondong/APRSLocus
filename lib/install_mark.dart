/// 安装标识的空中宣告（只做一次）。
///
/// 用户 2026-11-13：「当 aprslocus 第一次连接到 APRS 服务器广播自身安装标识…
/// 注意自身安装标识指示，广播到服务器上面，到信标状态信息」。所以标识写在
/// **状态报文**（DTI `>`）的正文里，随装好后第一次上线的那一帧出去。
///
/// 为什么不放别处：
///   * 不放位置报文的备注 —— 那是给人看「这个台站在哪儿、在干什么」的，
///     塞一串十六进制会把用户自己的备注挤掉（见 `AppState.myComment`）；
///   * 不单独再发一帧 —— aprs.fi 的「台站状态」只保留最后一帧，多一帧就多
///     一次闪，而上线那帧本来就要发。
///
/// 只留前 [keepHex] 位十六进制：`Blacklist.deviceId` 是 32 位随机十六进制，
/// 全文加上版本与平台会超过 APRS101 给状态信息字段的 62 个字符；12 位
/// （48 位随机）足够把两次安装区分开，也不会把整帧挤爆。
class InstallMark {
  /// 行上留几位十六进制。
  static const int keepHex = 12;

  /// 标记本身的前缀：一眼能看出这是安装标识而不是用户写的话。
  static const String label = 'ID:';

  /// 从一个安装标识算出行上那截标记（`ID:xxxxxxxxxxxx`）。
  ///
  /// 空标识返回 null —— 取不到就不报，不能在帧里留一个光秃秃的 `ID:`。
  static String? of(String deviceId) {
    final hex = deviceId.trim().toLowerCase().replaceAll(
          RegExp(r'[^0-9a-f]'),
          '',
        );
    if (hex.isEmpty) return null;
    final keep = hex.length <= keepHex ? hex : hex.substring(0, keepHex);
    return '$label$keep';
  }

  /// 首次上线那帧状态报文的正文：`<基础文本> ID:xxxxxxxxxxxx`。
  ///
  /// 超长时先砍基础文本、标记整段留着：标记是这一帧的目的，版本号砍掉不影响
  /// 服务器认出这是哪一次安装（[max] 与 `AppState.statusMaxLen` 同口径）。
  static String text(String base, String mark, {int max = 60}) {
    final room = max - mark.length - 1; // 还留一个空格
    var head = base.trim();
    if (room <= 0) return mark;
    if (head.length > room) head = head.substring(0, room).trim();
    return head.isEmpty ? mark : '$head $mark';
  }
}
