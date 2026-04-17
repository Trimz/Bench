import SwiftUI

struct ProjectCard: Identifiable {
    let id = UUID()
    let name: String
    let status: String
    let updatedLabel: String
    let summary: String
}

private let sampleProjects: [ProjectCard] = [
    ProjectCard(
        name: "Bench",
        status: "green",
        updatedLabel: "Updated 2h ago",
        summary: "Refined the implementation plan and started scaffolding the Vercel API and macOS app shell."
    ),
    ProjectCard(
        name: "Website Redesign",
        status: "yellow",
        updatedLabel: "Updated 5d ago",
        summary: "Design direction is set, but the project needs another written update before work resumes."
    ),
    ProjectCard(
        name: "Investor Memo",
        status: "red",
        updatedLabel: "No update in 19d",
        summary: "This project has gone stale and should be pulled back into focus by the ranking logic."
    )
]

struct ContentView: View {
    @State private var selectedProject = sampleProjects[0]
    @State private var draftUpdate = ""

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bench")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Projects ranked by attention")
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(sampleProjects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            projectRow(for: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(24)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationSplitViewColumnWidth(min: 320, ideal: 360)
    }

    private var detail: some View {
        HStack(spacing: 0) {
            summaryPanel
            Divider()
            updateHistory
            Divider()
            composerPanel
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var summaryPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Summary")
                .font(.title2.weight(.semibold))

            Text(selectedProject.summary)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var updateHistory: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(selectedProject.name)
                .font(.largeTitle.weight(.bold))

            Text(selectedProject.updatedLabel)
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.03))
                .overlay(
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Updates")
                            .font(.headline)
                        Text("The real update history will be loaded from the Bench API once auth and project endpoints are wired into the app.")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private var composerPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Update")
                .font(.title3.weight(.semibold))

            TextEditor(text: $draftUpdate)
                .font(.body)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            Button("Send Update") {
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .frame(minWidth: 320, maxWidth: 320, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    private func projectRow(for project: ProjectCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor(for: project.status))
                .frame(width: 10, height: 10)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text(project.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(project.updatedLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(project.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(selectedProject.id == project.id ? Color.accentColor.opacity(0.14) : Color.white.opacity(0.7))
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
}
