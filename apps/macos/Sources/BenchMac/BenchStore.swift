import Foundation
import SwiftUI

@MainActor
final class BenchStore: ObservableObject {
    enum AuthMode: String, CaseIterable, Identifiable {
        case login
        case register

        var id: String { rawValue }
        var title: String { self == .login ? "Log In" : "Create Account" }
        var alternateTitle: String { self == .login ? "Need an account?" : "Already have an account?" }
        var alternateButtonTitle: String { self == .login ? "Register" : "Log In" }
    }

    @Published var authMode: AuthMode = .login
    @Published var email = ""
    @Published var password = ""
    @Published var currentUser: BenchUser?
    @Published var projects: [BenchProject] = []
    @Published var selectedProjectID: String?
    @Published var updates: [BenchUpdate] = []
    @Published var draftUpdate = ""
    @Published var createProjectName = ""
    @Published var isPresentingCreateProject = false
    @Published var isLoading = false
    @Published var isSendingUpdate = false
    @Published var isCreatingProject = false
    @Published var errorMessage: String?

    private let client: APIClient

    init(client: APIClient = APIClient()) {
        self.client = client
    }

    var selectedProject: BenchProject? {
        guard let selectedProjectID else {
            return projects.first
        }

        return projects.first(where: { $0.id == selectedProjectID }) ?? projects.first
    }

    func bootstrap() async {
        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await client.currentUser()

            if currentUser != nil {
                try await reloadProjects()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitAuth() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Enter both email and password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            currentUser = try await (authMode == .login
                ? client.login(email: email, password: password)
                : client.register(email: email, password: password))
            password = ""
            errorMessage = nil
            try await reloadProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() async {
        do {
            try await client.logout()
            currentUser = nil
            projects = []
            updates = []
            selectedProjectID = nil
            draftUpdate = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reloadProjects() async throws {
        let fetchedProjects = try await client.fetchProjects()
        projects = fetchedProjects

        if let selectedProjectID, fetchedProjects.contains(where: { $0.id == selectedProjectID }) {
            try await refreshSelectedProject()
            return
        }

        selectedProjectID = fetchedProjects.first?.id
        try await refreshSelectedProject()
    }

    func selectProject(id: String) async {
        selectedProjectID = id

        do {
            try await refreshSelectedProject()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProject() async {
        let trimmedName = createProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Project name cannot be empty."
            return
        }

        isCreatingProject = true
        defer { isCreatingProject = false }

        do {
            let project = try await client.createProject(name: trimmedName)
            createProjectName = ""
            isPresentingCreateProject = false
            projects.insert(project, at: 0)
            selectedProjectID = project.id
            try await refreshSelectedProject()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendUpdate() async {
        guard let project = selectedProject else {
            errorMessage = "Select a project before sending an update."
            return
        }

        let trimmedDraft = draftUpdate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else {
            errorMessage = "Write an update before sending."
            return
        }

        isSendingUpdate = true
        defer { isSendingUpdate = false }

        do {
            _ = try await client.createUpdate(projectId: project.id, content: trimmedDraft)
            draftUpdate = ""
            try await reloadProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshSelectedProject() async throws {
        guard let selectedProjectID else {
            updates = []
            return
        }

        async let fetchedProject = client.fetchProject(id: selectedProjectID)
        async let fetchedUpdates = client.fetchUpdates(projectId: selectedProjectID)

        let project = try await fetchedProject
        updates = try await fetchedUpdates

        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.insert(project, at: 0)
        }

        projects.sort { $0.activityScore > $1.activityScore }
    }
}
