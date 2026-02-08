import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        ZStack {
            BrutalPalette.paper
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                HStack(spacing: 14) {
                    leftPanel
                        .frame(width: 360)
                    rightPanel
                }
                .padding(14)
            }

            if state.isBusy {
                VStack(spacing: 8) {
                    Text("WORKING")
                        .font(.custom("AvenirNextCondensed-Heavy", size: 24))
                    Text("Do not quit the app.")
                        .font(.custom("AvenirNext-Regular", size: 13))
                }
                .padding(24)
                .frame(width: 300)
                .background(BrutalPalette.accent)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 4))
                .shadow(color: .black.opacity(0.2), radius: 0, x: 8, y: 8)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BRUTALZIP")
                        .font(.custom("HelveticaNeue-CondensedBlack", size: 64))
                        .foregroundStyle(BrutalPalette.ink)
                    Text("OPEN SOURCE ZIP WAR MACHINE FOR MAC")
                        .font(.custom("AvenirNextCondensed-DemiBold", size: 16))
                        .tracking(3)
                        .foregroundStyle(BrutalPalette.ink.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(state.statusLine)
                        .font(.custom("AvenirNextCondensed-Heavy", size: 16))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(state.statusLine == "ERROR" ? BrutalPalette.error : (state.statusLine == "READY" ? BrutalPalette.signal : BrutalPalette.accent))
                        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
                        .shadow(color: .black.opacity(0.3), radius: 0, x: 4, y: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .background(BrutalPalette.panel)
            
            Rectangle()
                .fill(Color.black)
                .frame(height: 6)
        }
    }

    private var leftPanel: some View {
        ScrollView {
            VStack(spacing: 14) {
                BrutalCard(title: "CREATE ZIP") {
                    VStack(spacing: 10) {
                        BrutalButton(label: "Select Files/Folders", tone: .ink) {
                            state.chooseInputItems()
                        }

                        if state.selectedInputItems.isEmpty {
                            smallNote("No inputs selected")
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(state.selectedInputItems.prefix(5), id: \.path) { item in
                                    Text(item.lastPathComponent)
                                        .lineLimit(1)
                                        .font(.custom("AvenirNextCondensed-Regular", size: 12))
                                }
                                if state.selectedInputItems.count > 5 {
                                    smallNote("+\(state.selectedInputItems.count - 5) more")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.white)
                            .overlay(Rectangle().stroke(Color.black, lineWidth: 2))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Compression: \(Int(state.compressionLevel))")
                                .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                            Slider(value: $state.compressionLevel, in: 0...9, step: 1)
                                .tint(.black)
                        }

                        VStack(spacing: 8) {
                            SecureField("Create Password (optional)", text: $state.createPassword)
                                .textFieldStyle(BrutalFieldStyle())
                            TextField("Split size MB (optional)", text: $state.splitSizeMBText)
                                .textFieldStyle(BrutalFieldStyle())
                        }

                        BrutalButton(label: "Build Archive", tone: .accent) {
                            state.createArchiveFromSelection()
                        }
                    }
                }

                BrutalCard(title: "ARCHIVE OPS") {
                    VStack(spacing: 10) {
                        BrutalButton(label: "Open ZIP", tone: .ink) {
                            state.openArchive()
                        }

                        BrutalButton(label: "Refresh List", tone: .paper) {
                            state.refreshEntries()
                        }

                        BrutalButton(label: "Test Integrity", tone: .paper) {
                            state.testArchiveIntegrity()
                        }

                        BrutalButton(label: "Add Files", tone: .paper) {
                            state.addItemsToArchive()
                        }

                        BrutalButton(label: "Delete Selected", tone: .error) {
                            state.deleteSelectedEntries()
                        }

                        SecureField("Action Password", text: $state.actionPassword)
                            .textFieldStyle(BrutalFieldStyle())

                        Toggle("Overwrite on Extract", isOn: $state.overwriteOnExtract)
                            .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                            .toggleStyle(.checkbox)

                        BrutalButton(label: "Select Extract Folder", tone: .paper) {
                            state.chooseExtractionDestination()
                        }

                        BrutalButton(label: "Extract ZIP", tone: .signal) {
                            state.extractArchive()
                        }

                        if let destination = state.extractionDestination {
                            smallNote("Target: \(destination.path)")
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var rightPanel: some View {
        VStack(spacing: 14) {
            BrutalCard(title: "ARCHIVE CONTENT") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(state.selectedArchiveURL?.path ?? "No archive loaded")
                        .font(.custom("AvenirNextCondensed-Regular", size: 12))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    List(state.entries, selection: $state.selectedEntryNames) { entry in
                        HStack {
                            Text(entry.name)
                                .font(.custom("AvenirNextCondensed-DemiBold", size: 12))
                            Spacer()
                            Text("\(entry.size) B")
                                .font(.custom("AvenirNextCondensed-Regular", size: 11))
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 320)
                    .overlay(Rectangle().stroke(Color.black, lineWidth: 3))

                    smallNote("Tip: Use Cmd+Click for multi-select.")
                }
            }

            BrutalCard(title: "SYSTEM LOG") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(state.logs, id: \.self) { line in
                            Text(line)
                                .font(.custom("Menlo", size: 11))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .background(Color.white)
                                .overlay(Rectangle().stroke(Color.black, lineWidth: 1))
                        }
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    private func smallNote(_ text: String) -> some View {
        Text(text)
            .font(.custom("AvenirNextCondensed-Medium", size: 13))
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.black.opacity(1.0))
            .padding(.top, 4)
    }
}

private enum BrutalPalette {
    static let paper = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let panel = Color(red: 0.93, green: 0.90, blue: 0.84)
    static let accent = Color(red: 1.0, green: 0.33, blue: 0.1)
    static let signal = Color(red: 0.72, green: 0.92, blue: 0.38)
    static let error = Color(red: 1.0, green: 0.57, blue: 0.57)
    static let ink = Color.black
}

private struct BrutalCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.custom("AvenirNextCondensed-Heavy", size: 13))
                .tracking(1.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black)
                .foregroundStyle(.white)

            content
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BrutalPalette.panel)
        }
        .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        .shadow(color: .black.opacity(0.2), radius: 0, x: 6, y: 6)
    }
}

private struct BrutalButton: View {
    enum Tone {
        case ink
        case accent
        case signal
        case paper
        case error

        var background: Color {
            switch self {
            case .ink: return .black
            case .accent: return BrutalPalette.accent
            case .signal: return BrutalPalette.signal
            case .paper: return .white
            case .error: return BrutalPalette.error
            }
        }

        var foreground: Color {
            self == .ink ? .white : .black
        }
    }

    let label: String
    let tone: Tone
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label.uppercased())
                .font(.custom("AvenirNextCondensed-Heavy", size: 14))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(tone.background)
                .foregroundStyle(tone.foreground)
                .overlay(Rectangle().stroke(Color.black, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(0.15), radius: 0, x: 4, y: 4)
    }
}

private struct BrutalFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.custom("AvenirNextCondensed-Medium", size: 14))
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(Rectangle().stroke(Color.black, lineWidth: 2.5))
    }
}
