// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Tekkon

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

  /// Stronger gate for automatic mixed-token boundaries.
  ///
  /// A merely English-shaped token is not enough because many valid Hanyu-Pinyin
  /// strings also look word-like. We only accept the segment when it either has
  /// an unmistakably English repeated-letter pattern (for example `meeting`)
  /// or leaves at least two letters uncovered by the longest legal Pinyin prefix
  /// (for example `server`).
  static func isConfidentEnglishSegment(
    _ raw: String,
    parser: Tekkon.MandarinParser
  ) -> Bool {
    guard looksLikeEnglishWord(raw), parser.isPinyin else { return false }
    let normalized = raw.lowercased()
    let chars = Array(normalized)
    if chars.count >= 3 {
      for index in 0 ..< (chars.count - 2) where chars[index] == chars[index + 1] {
        return true
      }
    }

    let trie = Tekkon.PinyinTrie.shared(parser: parser)
    guard let pinyinMap = parser.mapZhuyinPinyin else { return false }
    var longestCoveredPrefixLength = 0
    for length in stride(from: normalized.count, through: 1, by: -1) {
      let prefix = String(normalized.prefix(length))
      let chopped = trie.chop(prefix)
      let isFullyCovered = !chopped.isEmpty
        && chopped.joined() == prefix
        && chopped.allSatisfy { pinyinMap[$0] != nil }
      if isFullyCovered {
        longestCoveredPrefixLength = length
        break
      }
    }
    return normalized.count - longestCoveredPrefixLength >= 2
  }
}
