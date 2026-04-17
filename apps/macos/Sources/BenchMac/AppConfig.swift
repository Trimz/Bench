import Foundation

enum AppConfig {
    static let defaultBaseURL = URL(string: "https://bench-rho.vercel.app")!

    static var apiBaseURL: URL {
        if let value = ProcessInfo.processInfo.environment["BENCH_API_BASE_URL"],
           let url = URL(string: value) {
            return url
        }

        return defaultBaseURL
    }
}
