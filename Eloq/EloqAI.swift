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

    nonisolated init(
        session: URLSession = .shared,
        model: String = "gpt-5-mini",
        reasoningEffort: String = "low"
    ) {
        self.session = session
        self.model = model
        self.reasoningEffort = reasoningEffort
    }

    func suggestConnections(
        for focusRole: RoleSummary,
        existingRoles: [RoleSummary],
        existingConnections: [ExistingConnectionSummary]
    ) async throws -> [SuggestionCandidate] {
        guard let apiKey = EloqKeychain.shared.openAIKey(), !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let systemPrompt = """
        You are Eloq, a linguistically conservative vocabulary coach.
        The user stores words in two buckets:
        - overused: words they lean on too much
        - underused: sharper words they want to reach for more often

        Suggest opposite-side connections for the focus word.
        Prefer common, realistic writing substitutions over dramatic synonyms.
        Reuse existing library words when possible.
        If you introduce a new counterpart term, keep it to four words or fewer.
        Never return the focus term itself.
        Never return duplicate counterpart terms.
        Keep rationale, useWhen, and caution concise and practical.
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
                            "confidence": ["type": "number"],
                        ],
                        "required": [
                            "counterpartTerm",
                            "rationale",
                            "useWhen",
                            "caution",
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
            "library": [
                "overused": existingRoles.filter { $0.kind == WordRoleKind.overused.rawValue }.map(\.term),
                "underused": existingRoles.filter { $0.kind == WordRoleKind.underused.rawValue }.map(\.term),
            ],
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
