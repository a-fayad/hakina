import Foundation

struct GeminiTranslator {

    static var apiKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String else {
            fatalError("GEMINI_API_KEY not found in Info.plist")
        }
        return key
    }

    static func translate(_ text: String, completion: @escaping (Result<String, Error>) -> Void) {

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0)))
            return
        }

        let prompt = """
        Translate the following text into Levantine Arabic (the dialect \
        spoken in Lebanon, Syria, Jordan, and Palestine). If the text is \
        already in Levantine Arabic, translate it into English instead. \
        Only return the translation, nothing else.

        Text: \(text)
        """

        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(NSError(domain: "EncodingError", code: 0)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "NoData", code: 0)))
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let content = candidates.first?["content"] as? [String: Any],
                   let parts = content["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    completion(.success(text.trimmingCharacters(in: .whitespacesAndNewlines)))
                } else {
                    let raw = String(data: data, encoding: .utf8) ?? "unreadable response"
                    completion(.failure(NSError(domain: "ParseError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not parse response: \(raw)"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
