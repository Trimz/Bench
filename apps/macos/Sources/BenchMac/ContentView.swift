import SwiftUI

struct ContentView: View {
    @StateObject private var store = BenchStore()

    var body: some View {
        Group {
            if store.currentUser == nil {
                authView
            } else {
                appView
            }
        }
        .task {
            await store.bootstrap()
        }
        .alert("Bench", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { newValue in
                if !newValue {
                    store.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "Something went wrong.")
        }
        .sheet(isPresented: $store.isPresentingCreateProject) {
            createProjectSheet
        }
    }

    private var authView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.93, blue: 0.88),
                    Color(red: 0.90, green: 0.94, blue: 0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Bench")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Track the projects that need your attention.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    TextField("Email", text: $store.email)
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $store.password)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    Task {
                        await store.submitAuth()
                    }
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(store.authMode.title)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(store.isLoading)

                HStack(spacing: 6) {
                    Text(store.authMode.alternateTitle)
                        .foregroundStyle(.secondary)

                    Button(store.authMode.alternateButtonTitle) {
                        store.authMode = store.authMode == .login ? .register : .login
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .padding(28)
            .frame(width: 420)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 24, x: 0, y: 20)
        }
    }

    private var appView: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bench")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text(store.currentUser?.email ?? "")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.isPresentingCreateProject = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            if store.projects.isEmpty {
                ContentUnavailableView(
                    "No Projects Yet",
                    systemImage: "square.stack.3d.up",
                    description: Text("Create your first project to start building a ranked Bench stack.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(store.projects) { project in
                            Button {
                                Task {
                                    await store.selectProject(id: project.id)
                                }
                            } label: {
                                projectRow(for: project)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer(minLength: 0)

            Button("Log Out") {
                Task {
                    await store.logout()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationSplitViewColumnWidth(min: 320, ideal: 360)
    }

    @ViewBuilder
    private var detail: some View {
        if let project = store.selectedProject {
            HStack(spacing: 0) {
                summaryPanel(for: project)
                Divider()
                updatesPanel(for: project)
                Divider()
                composerPanel
            }
            .background(Color(nsColor: .controlBackgroundColor))
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "sidebar.left",
                description: Text("Choose a project from the sidebar or create a new one.")
            )
        }
    }

    private func summaryPanel(for project: BenchProject) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Summary")
                .font(.title2.weight(.semibold))

            Text(project.summary ?? "No summary yet. Send an update to generate the first project snapshot.")
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func updatesPanel(for project: BenchProject) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project.name)
                .font(.largeTitle.weight(.bold))

            Text(lastUpdatedLabel(for: project.lastUpdateAt))
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if store.updates.isEmpty {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.03))
                            .frame(height: 180)
                            .overlay(
                                Text("No updates yet. Write the first one on the right.")
                                    .foregroundStyle(.secondary)
                            )
                    } else {
                        ForEach(store.updates) { update in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(relativeDateLabel(for: update.createdAt))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Text(update.content)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.75))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var composerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Update")
                .font(.title3.weight(.semibold))

            TextEditor(text: $store.draftUpdate)
                .font(.body)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Button {
                Task {
                    await store.sendUpdate()
                }
            } label: {
                if store.isSendingUpdate {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Send Update")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.selectedProject == nil || store.isSendingUpdate)

            Spacer()
        }
        .frame(minWidth: 320, maxWidth: 320, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var createProjectSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New Project")
                .font(.title2.weight(.semibold))

            TextField("Project name", text: $store.createProjectName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    store.isPresentingCreateProject = false
                    store.createProjectName = ""
                }

                Button {
                    Task {
                        await store.createProject()
                    }
                } label: {
                    if store.isCreatingProject {
                        ProgressView()
                    } else {
                        Text("Create")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 360)
    }

    private func projectRow(for project: BenchProject) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor(for: project.recencyStatus))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(lastUpdatedLabel(for: project.lastUpdateAt))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(project.summary ?? "No summary yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(store.selectedProjectID == project.id ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "green":
            return Color(red: 0.12, green: 0.64, blue: 0.42)
        case "yellow":
            return Color(red: 0.82, green: 0.65, blue: 0.13)
        default:
            return Color(red: 0.8, green: 0.24, blue: 0.22)
        }
    }

    private func lastUpdatedLabel(for date: Date?) -> String {
        guard let date else {
            return "No updates yet"
        }

        return "Updated \(relativeDateLabel(for: date))"
    }

    private func relativeDateLabel(for date: Date) -> String {
        RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
    }
}
