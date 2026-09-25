// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

enum MixTypeEnglishIntent {
  /// Conservative ASCII word-shape hint used only when Hybrid has no strong Chinese source.
  ///
  /// This deliberately does not try to be an English dictionary. It only recognizes longer
  /// Latin tokens with enough vowels to look word-like, while leaving consonant-heavy initials
  /// such as `tdny`, `ysxb`, or `jngsfa` available to the Chinese abbreviation provider.
  static func looksLikeEnglishWord(_ raw: String) -> Bool {
    let lower = raw.lowercased()
    guard lower.count >= 4,
          lower.range(of: "^[a-z]+$", options: .regularExpression) != nil
    else {
      return false
    }
    let vowelCount = lower.reduce(into: 0) { count, char in
      if "aeiou".contains(char) { count += 1 }
    }
    return vowelCount >= 2
  }
}
