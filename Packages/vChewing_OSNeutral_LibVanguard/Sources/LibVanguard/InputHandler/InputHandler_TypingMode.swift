// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - TypingMode

/// 打字模式枚舉：描述「vChewingFactory 輸入方法」之下（即注音／拼音／磁帶系）的輸入風格。
///
/// 注意：`TypingMethod`（vChewingFactory／codePoint／haninKeyboardSymbol／romanNumerals）
/// 是另一層「輸入方法」概念，兩者勿混淆。本枚舉僅在 `currentTypingMethod == .vChewingFactory`
/// 時有意義。
public enum TypingMode: String, Equatable {
  /// 磁帶（Cin Cassette）模式：以使用者提供的鍵盤對照表輸入（雙拼、部首筆畫等由磁帶承載）。
  case cassette
  /// MixType Hybrid：以單一路由協調 CIN 與拼音；Phase A 先維持磁帶相容行為。
  case hybridCassettePinyin
  /// 注音鍵盤模式（Bopomofo Keyblock）。
  case bopomofoKeyblock
  /// 拼音鍵盤模式（Hanyu Pinyin Keyblock）。
  case pinyinKeyblock
  /// 狂拼模式（Furious Typing）：拼音鍵盤＋快速自動 chop 組句。
  case pinyinFuriousTyping

  // MARK: Public

  /// 該打字模式用於「內文模式提示」（於對接輸入客體時顯示）的 i18n key。
  public var i18nKey4InlineModeHint: String {
    "i18n:TypingMode.i18nKey4InlineModeHint.\(rawValue)"
  }
}

extension InputHandlerProtocol {
  /// MixType 智慧層目前所依附的基礎輸入來源。
  public var mixTypeBaseInputProvider: Shared.MixTypeBaseInputProvider {
    prefs.mixTypeBaseInputProvider
  }

  /// 當前打字模式（於 `currentTypingMethod == .vChewingFactory` 時才有意義）。
  ///
  /// 判定順序：Hybrid 僅在磁帶＋Hybrid 偏好＋拼音偏好＋實際拼音 parser 四者皆成立時啟用；
  /// 其餘磁帶情境維持原本 .cassette。非磁帶時，狂拼要求狂拼開關＋非逐字選字＋拼音注拼槽；
  /// 其餘以注拼槽是否拼音區分拼音鍵盤／注音鍵盤。
  /// `furiousTypingEnabled` pref 保留為「快速切換」的底層開關，本枚舉是其語義化抽象。
  public var typingMode: TypingMode {
    if mixTypeBaseInputProvider == .cin {
      if prefs.hybridCassettePinyinEnabled, prefs.pinyinTypingEnabled, composer.isPinyinMode {
        return .hybridCassettePinyin
      }
      return .cassette
    }
    if prefs.furiousTypingEnabled, !prefs.useSCPCTypingMode, composer.isPinyinMode {
      return .pinyinFuriousTyping
    }
    return composer.isPinyinMode ? .pinyinKeyblock : .bopomofoKeyblock
  }
}
