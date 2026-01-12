import Foundation

struct RetailDealDTO: Decodable, Identifiable {
    let id = UUID()
    let brand: String
    let headline: String
    let subheadline: String
    let tintHex: String
}

struct RetailerDTO: Decodable, Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let tags: [String]
    let rating: Double
    let perkText: String
    let etaText: String
    let freeDelivery: Bool
    let logoHex: String
    let categories: [String]
}

enum RetailAPIError: Error {
    case invalidResponse
    case http(Int)
}

final class RetailAPI {
    static let shared = RetailAPI()

    // Replace with your deployed URL; consider moving to Info.plist/xcconfig
    var baseURL = URL(string: "http://127.0.0.1:8000")!
    var apiKey = "dev-key-123"

    private let decoder = JSONDecoder()

    func deals(search: String? = nil) async throws -> [RetailDealDTO] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/deals"), resolvingAgainstBaseURL: false)!
        if let q = search, !q.trimmingCharacters(in: .whitespaces).isEmpty {
            comps.queryItems = [URLQueryItem(name: "q", value: q)]
        }
        var req = URLRequest(url: comps.url!)
        req.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RetailAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RetailAPIError.http(http.statusCode) }
        return try decoder.decode([RetailDealDTO].self, from: data)
    }

    func retailers(category: String? = nil, search: String? = nil) async throws -> [RetailerDTO] {
        var comps = URLComponents(url: baseURL.appendingPathComponent("/retailers"), resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = []
        if let c = category, !c.isEmpty { items.append(URLQueryItem(name: "category", value: c)) }
        if let q = search, !q.trimmingCharacters(in: .whitespaces).isEmpty { items.append(URLQueryItem(name: "q", value: q)) }
        if !items.isEmpty { comps.queryItems = items }

        var req = URLRequest(url: comps.url!)
        req.addValue(apiKey, forHTTPHeaderField: "X-API-Key")
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw RetailAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw RetailAPIError.http(http.statusCode) }
        return try decoder.decode([RetailerDTO].self, from: data)
    }
}
