//
//  AIProviderPreset.swift
//  TablePro
//

import Foundation

/// A named vendor that speaks the OpenAI-compatible wire format.
///
/// A preset is stored as a `.custom` provider carrying the preset's id, so a build that has never
/// heard of the vendor still decodes it as a working custom provider. A new `AIProviderType` case
/// cannot do that: its raw value fails to decode on every older build that syncs the same settings.
struct AIProviderPreset: Identifiable, Equatable, Sendable {
    let id: String
    let displayName: String
    let endpoint: String
    let symbolName: String
    let authStyle: AIProviderType.AuthStyle
    /// Set when the vendor's 403 means the key itself is wrong or lacks access. Read as a server
    /// error, it is offered for a retry that can never succeed.
    let treatsForbiddenAsAuthFailure: Bool

    /// Answers a wrong key with 403.
    static let requesty = AIProviderPreset(
        id: "requesty",
        displayName: "Requesty",
        endpoint: "https://router.requesty.ai",
        symbolName: "arrow.triangle.branch",
        authStyle: .apiKey,
        treatsForbiddenAsAuthFailure: true
    )

    /// Built on New API, which answers a wrong key with 401 and a key barred from the model, its
    /// group or the client's IP with 403.
    static let apiRoute = AIProviderPreset(
        id: "api-route",
        displayName: "API Route",
        endpoint: "https://global.api-route.com",
        symbolName: "network",
        authStyle: .apiKey,
        treatsForbiddenAsAuthFailure: true
    )

    static let all: [AIProviderPreset] = [.requesty, .apiRoute]

    static func preset(withID id: String?) -> AIProviderPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}
