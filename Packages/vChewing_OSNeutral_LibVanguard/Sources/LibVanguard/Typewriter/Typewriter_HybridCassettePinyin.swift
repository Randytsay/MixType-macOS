// (c) 2026 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - HybridCassettePinyinTypewriter

/// MixType Hybrid CIN + Pinyin 的單一事件分派入口。
///
/// Phase A 僅建立 ownership seam：每個事件只會進入一個 typewriter。候選雙路探測與合併
/// 由後續 Phase B 在此入口內協調，避免兩個既有 typewriter 依序修改同一份 handler state。
@frozen
public struct HybridCassettePinyinTypewriter<Handler: InputHandlerProtocol>: TypewriterProtocol {
  // MARK: Lifecycle

  public init(_ handler: Handler) {
    self.handler = handler
  }

  // MARK: Public

  public let handler: Handler

  public func handle(_ input: some InputSignalProtocol) -> Bool? {
    CassetteTypewriter(handler).handle(input)
  }
}
