//
//  AIProviderPresetTests.swift
//  TableProTests
//

import Foundation
@testable import TablePro
import Testing

struct AIProviderPresetTests {
    init() {
        AIProviderRegistration.registerAll()
    }

    /// Taken from each vendor's own docs, so a new preset cannot pass on a Base URL that only
    /// looks right.
    private static let documentedRoutes: [String: (chat: String, models: String)] = [
        "requesty": (
            "https://router.requesty.ai/v1/chat/completions",
            "https://router.requesty.ai/v1/models"
        ),
        "api-route": (
            "https://global.api-route.com/v1/chat/completions",
            "https://global.api-route.com/v1/models"
        )
    ]

    @Test("Every preset has a unique id and an https endpoint the transport can resolve")
    func presetsAreWellFormed() {
        #expect(Set(AIProviderPreset.all.map(\.id)).count == AIProviderPreset.all.count)
        for preset in AIProviderPreset.all {
            #expect(AIProviderPreset.preset(withID: preset.id) == preset)
            #expect(preset.endpoint.hasPrefix("https://"), "\(preset.id) must default to https")
            #expect(AIEndpoint(preset.endpoint, style: .chatCompletions) != nil, "\(preset.id) endpoint must resolve")
        }
        #expect(AIProviderPreset.preset(withID: nil) == nil)
        #expect(AIProviderPreset.preset(withID: "no-such-vendor") == nil)
    }

    @Test("A preset's default Base URL resolves to the chat and model routes its vendor documents",
          arguments: AIProviderPreset.all)
    func defaultBaseURLResolvesToTheVendorRoutes(preset: AIProviderPreset) throws {
        let routes = try #require(Self.documentedRoutes[preset.id], "\(preset.id) has no documented routes")
        let config = AIProviderConfig(preset: preset)
        let style = config.type.endpointStyle
        let endpoint = try #require(AIEndpoint(config.endpoint, style: style))
        #expect(endpoint.chatURL(model: "vendor/model-1", style: style)?.absoluteString == routes.chat)
        #expect(endpoint.url(appending: style.modelsResource)?.absoluteString == routes.models)
    }

    @Test("A provider added from a preset is a custom provider that reads as the vendor",
          arguments: AIProviderPreset.all)
    func presetConfigReadsAsTheVendor(preset: AIProviderPreset) {
        let config = AIProviderConfig(preset: preset)
        #expect(config.type == .custom)
        #expect(config.presetID == preset.id)
        #expect(config.preset == preset)
        #expect(config.name == preset.displayName)
        #expect(config.endpoint == preset.endpoint)
        #expect(config.kindName == preset.displayName)
        #expect(config.symbolName == preset.symbolName)
        #expect(config.authStyle == preset.authStyle)
    }

    @Test("A preset provider whose name was cleared still shows the vendor, not Custom",
          arguments: AIProviderPreset.all)
    func clearedNameFallsBackToTheVendor(preset: AIProviderPreset) {
        var config = AIProviderConfig(preset: preset)
        config.name = ""
        #expect(config.displayName == preset.displayName)
    }

    @Test("A plain custom provider keeps its own name, icon and optional key")
    func plainCustomIsUnchanged() {
        let config = AIProviderConfig(type: .custom, endpoint: "https://api.z.ai/api/paas/v4")
        #expect(config.preset == nil)
        #expect(config.kindName == AIProviderType.custom.displayName)
        #expect(config.symbolName == AIProviderType.custom.symbolName)
        #expect(config.authStyle == .optionalApiKey)
        #expect(config.defaultEndpoint.isEmpty)
    }

    @Test("A preset id on a provider that is not custom changes nothing")
    func presetOnlyAppliesToCustom() {
        let config = AIProviderConfig(type: .openRouter, presetID: "requesty")
        #expect(config.preset == nil)
        #expect(config.endpoint == AIProviderType.openRouter.defaultEndpoint)
        #expect(config.kindName == "OpenRouter")
    }

    /// The point of a preset over a new provider type: the stored type is one every released
    /// build already decodes, so settings synced to an older build keep all their providers.
    @Test("A preset provider is stored under the custom type, which older builds decode",
          arguments: AIProviderPreset.all)
    func storedTypeIsCustom(preset: AIProviderPreset) throws {
        let data = try JSONEncoder().encode(AIProviderConfig(preset: preset))
        let object = try JSONSerialization.jsonObject(with: data)
        let json = try #require(object as? [String: Any])
        #expect(json["type"] as? String == "custom")
        #expect(json["presetID"] as? String == preset.id)
        #expect(json["name"] as? String == preset.displayName)
        #expect(json["endpoint"] as? String == preset.endpoint)
    }

    @Test("A preset provider keeps its model and edited Base URL through an encode and decode",
          arguments: AIProviderPreset.all)
    func roundTrips(preset: AIProviderPreset) throws {
        var config = AIProviderConfig(preset: preset)
        config.model = "vendor/model-1"
        config.endpoint = "https://proxy.example.com"
        let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: JSONEncoder().encode(config))
        #expect(decoded == config)
        #expect(decoded.preset == preset)
        #expect(decoded.authStyle == preset.authStyle)
    }

    @Test("A stored preset provider with no endpoint decodes to the preset's default",
          arguments: AIProviderPreset.all)
    func emptyEndpointDecodesToThePresetDefault(preset: AIProviderPreset) throws {
        let json = #"""
        {"id":"11111111-2222-3333-4444-555555555555","type":"custom","presetID":"\#(preset.id)","endpoint":""}
        """#
        let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: Data(json.utf8))
        #expect(decoded.endpoint == preset.endpoint)
    }

    @Test("A custom provider saved before presets existed decodes with none")
    func legacyCustomDecodes() throws {
        let json = #"{"id":"11111111-2222-3333-4444-555555555555","type":"custom","name":"vLLM","endpoint":"http://gpu:8000"}"#
        let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: Data(json.utf8))
        #expect(decoded.presetID == nil)
        #expect(decoded.authStyle == .optionalApiKey)
        #expect(decoded.displayName == "vLLM")
    }

    /// A preset this build has never heard of comes from a newer build over sync. It has to keep
    /// working as the custom provider it is stored as, and keep its id for the build that knows it.
    @Test("A preset id this build does not know behaves as custom and is written back unchanged")
    func unknownPresetIsKept() throws {
        let json = #"""
        {"id":"11111111-2222-3333-4444-555555555555","type":"custom","presetID":"vendor-from-the-future",
         "name":"Future","endpoint":"https://api.future.example"}
        """#
        let decoded = try JSONDecoder().decode(AIProviderConfig.self, from: Data(json.utf8))
        #expect(decoded.preset == nil)
        #expect(decoded.authStyle == .optionalApiKey)
        #expect(decoded.displayName == "Future")
        #expect(decoded.endpoint == "https://api.future.example")

        let reencoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(decoded)) as? [String: Any]
        #expect(reencoded?["presetID"] as? String == "vendor-from-the-future")
    }

    @Test("A preset provider builds the OpenAI-compatible transport", arguments: AIProviderPreset.all)
    func buildsTheSharedTransport(preset: AIProviderPreset) throws {
        let descriptor = try #require(AIProviderRegistry.shared.descriptor(for: AIProviderType.custom.rawValue))
        let config = AIProviderConfig(preset: preset)
        #expect(descriptor.makeProvider(config, "key") is OpenAICompatibleProvider)
        #expect(AIProviderFactory.makeUncachedProvider(for: config, apiKey: "key") is OpenAICompatibleProvider)
    }

    @Test("A preset that requires a key holds the model list until one is typed, and no longer",
          arguments: AIProviderPreset.all)
    func modelListWaitsForTheKey(preset: AIProviderPreset) {
        let config = AIProviderConfig(preset: preset)
        let descriptor = AIProviderRegistry.shared.descriptor(for: config.type.rawValue)
        let expected: AIModelListFetchGate.Blocker? = preset.authStyle == .apiKey ? .missingAPIKey : nil
        #expect(AIProviderDraftRules.modelListBlocker(descriptor: descriptor, draft: config, apiKey: "") == expected)
        #expect(AIProviderDraftRules.modelListBlocker(descriptor: descriptor, draft: config, apiKey: "sk-live") == nil)
    }
}
