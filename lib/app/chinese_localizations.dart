import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 本应用实际使用的返回按钮、文本编辑菜单、刷新及无障碍提示。
/// 采用SDK基础实现作有限覆盖，不宣称为通用中文组件库；新增日期选择器等组件时需扩展。
/// 不引入flutter_localizations：当前SDK将intl固定为0.20.2，会改变原项目0.20.3锁。
const chineseDelegates = <LocalizationsDelegate<dynamic>>[
  _ChineseMaterialDelegate(),
  _ChineseWidgetsDelegate(),
  _ChineseCupertinoDelegate(),
];

class _ChineseMaterial extends DefaultMaterialLocalizations {
  const _ChineseMaterial();
  @override
  String get backButtonTooltip => '返回';
  @override
  String get clearButtonTooltip => '清除文本';
  @override
  String get closeButtonTooltip => '关闭';
  @override
  String get deleteButtonTooltip => '删除';
  @override
  String get moreButtonTooltip => '更多';
  @override
  String get searchFieldLabel => '搜索';
  @override
  String get cancelButtonLabel => '取消';
  @override
  String get closeButtonLabel => '关闭';
  @override
  String get continueButtonLabel => '继续';
  @override
  String get copyButtonLabel => '复制';
  @override
  String get cutButtonLabel => '剪切';
  @override
  String get scanTextButtonLabel => '扫描文本';
  @override
  String get okButtonLabel => '确定';
  @override
  String get pasteButtonLabel => '粘贴';
  @override
  String get selectAllButtonLabel => '全选';
  @override
  String get lookUpButtonLabel => '查询';
  @override
  String get searchWebButtonLabel => '网页搜索';
  @override
  String get shareButtonLabel => '分享';
  @override
  String get modalBarrierDismissLabel => '关闭';
  @override
  String get menuDismissLabel => '关闭菜单';
  @override
  String get refreshIndicatorSemanticLabel => '刷新';
  @override
  String get popupMenuLabel => '弹出菜单';
  @override
  String get dialogLabel => '对话框';
  @override
  String get alertDialogLabel => '提示';
  @override
  String get selectedDateLabel => '已选择';
  @override
  String get currentDateLabel => '今天';
}

class _ChineseMaterialDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _ChineseMaterialDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(const _ChineseMaterial());
  @override
  bool shouldReload(_ChineseMaterialDelegate old) => false;
}

class _ChineseWidgetsDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _ChineseWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';
  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture(const DefaultWidgetsLocalizations());
  @override
  bool shouldReload(_ChineseWidgetsDelegate old) => false;
}

class _ChineseCupertino extends DefaultCupertinoLocalizations {
  const _ChineseCupertino();
  @override
  String get copyButtonLabel => '复制';
  @override
  String get cutButtonLabel => '剪切';
  @override
  String get pasteButtonLabel => '粘贴';
  @override
  String get selectAllButtonLabel => '全选';
  @override
  String get lookUpButtonLabel => '查询';
  @override
  String get searchWebButtonLabel => '网页搜索';
  @override
  String get shareButtonLabel => '分享';
  @override
  String get modalBarrierDismissLabel => '关闭';
}

class _ChineseCupertinoDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _ChineseCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'zh';
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      SynchronousFuture(const _ChineseCupertino());
  @override
  bool shouldReload(_ChineseCupertinoDelegate old) => false;
}
