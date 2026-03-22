import Foundation

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case requestEncodingFailed
    case invalidResponseStatus(Int, String)
    case emptyOutput
    case malformedPayload

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI key not found in Keychain."
        case .requestEncodingFailed:
            return "Failed to encode the OpenAI request."
        case let .invalidResponseStatus(status, body):
            return "OpenAI returned HTTP \(status): \(body)"
        case .emptyOutput:
            return "OpenAI returned an empty suggestion response."
        case .malformedPayload:
            return "OpenAI returned malformed suggestion JSON."
        }
    }
}

struct OpenAISuggestionService: Sendable {
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let model: String
    private let reasoningEffort: String
    private let apiKeyProvider: @MainActor @Sendable () -> String?

    nonisolated init(
        session: URLSession = .shared,
        model: String = "gpt-5-mini",
        reasoningEffort: String = "low",
        apiKeyProvider: @escaping @MainActor @Sendable () -> String? = {
            EloqKeychain.shared.openAIKey()
        }
    ) {
        self.session = session
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.apiKeyProvider = apiKeyProvider
    }

    static func oppositeKind(for focusKind: String) -> String {
        focusKind == WordRoleKind.overused.rawValue
            ? WordRoleKind.underused.rawValue
            : WordRoleKind.overused.rawValue
    }

    static func directionGuidance(for focusRole: RoleSummary) -> String {
        switch focusRole.kind {
        case WordRoleKind.underused.rawValue:
            return """
            The focus word is underused. Suggest overused/default words or phrases people commonly fall back to instead of "\(focusRole.term)".
            The counterpart terms should usually feel more generic, more habitual, or less precise than the focus word.
            """
        default:
            return """
            The focus word is overused. Suggest sharper underused words or phrases the user could reach for instead of "\(focusRole.term)".
            The counterpart terms should usually feel more precise, more vivid, or more specific than the focus word.
            """
        }
    }

    static func mixGuidance(for oppositeLibraryTerms: [String]) -> String {
        if oppositeLibraryTerms.isEmpty {
            return """
            The opposite-side library is empty, so fill the list with the best natural counterparts you can find.
            """
        }

        return """
        The UI already shows opposite-side library words separately. Complement that list instead of echoing it.
        Return a mixed shortlist with mostly new counterpart terms that are not already in the opposite-side library.
        Include no more than two library reuses unless there is no credible novel option.
        Aim for at least three novel counterpart terms when possible.
        """
    }

    func suggestConnections(
        for focusRole: RoleSummary,
        existingRoles: [RoleSummary],
        existingConnections: [ExistingConnectionSummary]
    ) async throws -> [SuggestionCandidate] {
        guard let apiKey = apiKeyProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let oppositeKind = Self.oppositeKind(for: focusRole.kind)
        let oppositeLibraryTerms = existingRoles
            .filter { $0.kind == oppositeKind }
            .map(\.term)

        let systemPrompt = """
        You are Eloq, a linguistically conservative vocabulary coach.
        The user stores words in two buckets:
        - overused: words they lean on too much
        - underused: sharper words they want to reach for more often

        Suggest opposite-side connections for the focus word.
        \(Self.directionGuidance(for: focusRole))
        Prefer common, realistic writing substitutions over dramatic synonyms.
        Reuse existing library words sparingly and only when they are clearly the best fit.
        \(Self.mixGuidance(for: oppositeLibraryTerms))
        If you introduce a new counterpart term, keep it to four words or fewer.
        Never return the focus term itself.
        Never return duplicate counterpart terms.
        Keep rationale, useWhen, and caution concise and practical.
        Also provide one short example sentence that uses the counterpart term naturally.
        """

        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "suggestions": [
                    "type": "array",
                    "maxItems": 6,
                    "items": [
                        "type": "object",
                        "properties": [
                            "counterpartTerm": ["type": "string"],
                            "rationale": ["type": "string"],
                            "useWhen": ["type": "string"],
                            "caution": ["type": "string"],
                            "exampleUsage": ["type": "string"],
                            "confidence": ["type": "number"],
                        ],
                        "required": [
                            "counterpartTerm",
                            "rationale",
                            "useWhen",
                            "caution",
                            "exampleUsage",
                            "confidence",
                        ],
                        "additionalProperties": false,
                    ],
                ],
            ],
            "required": ["suggestions"],
            "additionalProperties": false,
        ]

        let userPayload: [String: Any] = [
            "focusWord": [
                "term": focusRole.term,
                "kind": focusRole.kind,
            ],
            "requestedCounterpartKind": oppositeKind,
            "library": [
                "overused": existingRoles.filter { $0.kind == WordRoleKind.overused.rawValue }.map(\.term),
                "underused": existingRoles.filter { $0.kind == WordRoleKind.underused.rawValue }.map(\.term),
            ],
            "oppositeSideLibrary": oppositeLibraryTerms,
            "existingConnections": existingConnections.map {
                [
                    "overused": $0.overused,
                    "underused": $0.underused,
                    "status": $0.status,
                ]
            },
        ]

        let body: [String: Any] = [
            "model": model,
            "input": [
                [
                    "role": "system",
                    "content": [
                        ["type": "input_text", "text": systemPrompt],
                    ],
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": jsonString(userPayload)],
                    ],
                ],
            ],
            "reasoning": [
                "effort": reasoningEffort,
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "eloq_connection_suggestions",
                    "strict": true,
                    "schema": schema,
                ],
            ],
            "max_output_tokens": 900,
            "store": false,
        ]

        guard JSONSerialization.isValidJSONObject(body),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw AIServiceError.requestEncodingFailed
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.malformedPayload
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "No body"
            throw AIServiceError.invalidResponseStatus(httpResponse.statusCode, bodyText)
        }

        let outputText = try extractOutputText(from: data)
        guard let outputData = outputText.data(using: .utf8) else {
            throw AIServiceError.emptyOutput
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(AIGraphSuggestionPayload.self, from: outputData)
        return payload.suggestions
    }

    private func extractOutputText(from data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = object["output"] as? [[String: Any]] else {
            throw AIServiceError.malformedPayload
        }

        for item in output {
            guard item["type"] as? String == "message",
                  let contents = item["content"] as? [[String: Any]] else {
                continue
            }

            for content in contents where content["type"] as? String == "output_text" {
                if let text = content["text"] as? String, !text.isEmpty {
                    return text
                }
            }
        }

        throw AIServiceError.emptyOutput
    }

    private func jsonString(_ value: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }

        return text
    }
}
