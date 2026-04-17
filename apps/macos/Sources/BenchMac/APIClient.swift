import Foundation

struct BenchUser: Codable {
    let id: String
    let email: String
    let createdAt: Date
}

struct BenchProject: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let lastUpdateAt: Date?
    let activityScore: Double
    let recencyStatus: String
    let updateCount: Int
    let summary: String?
}

struct BenchUpdate: Codable, Identifiable, Hashable {
    let id: String
    let projectId: String
    let content: String
    let createdAt: Date
}

struct APIErrorResponse: Codable {
    let error: String
}

struct AuthEnvelope: Codable {
    let user: BenchUser?
}

struct ProjectsEnvelope: Codable {
    let projects: [BenchProject]
}

struct ProjectEnvelope: Codable {
    let project: BenchProject
}

struct UpdatesEnvelope: Codable {
    let updates: [BenchUpdate]
}

struct UpdateEnvelope: Codable {
    let update: BenchUpdate
}

@MainActor
final class APIClient {
    enum ClientError: LocalizedError {
        case invalidResponse
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "The server returned an invalid response."
            case let .http(_, message):
                return message
            }
        }
    }

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(baseURL: URL = AppConfig.apiBaseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.waitsForConnectivity = true

        self.session = URLSession(configuration: configuration)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)

            if let date = parseBenchDate(value) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(value)"
            )
        }
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func currentUser() async throws -> BenchUser? {
        let request = try makeRequest(path: "/api/auth/me", method: "GET", body: nil)
        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        if response.statusCode == 401 {
            return nil
        }

        guard (200 ... 299).contains(response.statusCode) else {
            let apiError = try? decoder.decode(APIErrorResponse.self, from: data)
            throw ClientError.http(response.statusCode, apiError?.error ?? "Request failed.")
        }

        return try decoder.decode(AuthEnvelope.self, from: data).user
    }

    func login(email: String, password: String) async throws -> BenchUser {
        let envelope: AuthEnvelope = try await send(
            path: "/api/auth/login",
            method: "POST",
            body: ["email": email, "password": password]
        )

        guard let user = envelope.user else {
            throw ClientError.invalidResponse
        }

        return user
    }

    func register(email: String, password: String) async throws -> BenchUser {
        let envelope: AuthEnvelope = try await send(
            path: "/api/auth/register",
            method: "POST",
            body: ["email": email, "password": password]
        )

        guard let user = envelope.user else {
            throw ClientError.invalidResponse
        }

        return user
    }

    func logout() async throws {
        let _: EmptyResponse = try await send(path: "/api/auth/logout", method: "POST")
    }

    func fetchProjects() async throws -> [BenchProject] {
        let envelope: ProjectsEnvelope = try await send(path: "/api/projects")
        return envelope.projects
    }

    func createProject(name: String) async throws -> BenchProject {
        let envelope: ProjectEnvelope = try await send(
            path: "/api/projects",
            method: "POST",
            body: ["name": name]
        )
        return envelope.project
    }

    func fetchProject(id: String) async throws -> BenchProject {
        let envelope: ProjectEnvelope = try await send(path: "/api/projects/\(id)")
        return envelope.project
    }

    func fetchUpdates(projectId: String) async throws -> [BenchUpdate] {
        let envelope: UpdatesEnvelope = try await send(path: "/api/projects/\(projectId)/updates")
        return envelope.updates
    }

    func createUpdate(projectId: String, content: String) async throws -> BenchUpdate {
        let envelope: UpdateEnvelope = try await send(
            path: "/api/projects/\(projectId)/updates",
            method: "POST",
            body: ["content": content]
        )
        return envelope.update
    }

    private func send<T: Decodable>(
        path: String,
        method: String = "GET",
        body: [String: String]? = nil
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, body: body)

        let (data, response) = try await session.data(for: request)

        guard let response = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200 ... 299).contains(response.statusCode) else {
            let apiError = try? decoder.decode(APIErrorResponse.self, from: data)
            throw ClientError.http(response.statusCode, apiError?.error ?? "Request failed.")
        }

        return try decoder.decode(T.self, from: data)
    }

    private func makeRequest(
        path: String,
        method: String,
        body: [String: String]?
    ) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw ClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}

private struct EmptyResponse: Decodable {}

private func parseBenchDate(_ value: String) -> Date? {
    let formatterWithFractional = ISO8601DateFormatter()
    formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    if let date = formatterWithFractional.date(from: value) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}
