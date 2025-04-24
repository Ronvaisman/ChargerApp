import SwiftUI

struct SessionsView: View {
    @ObservedObject var viewModel: ChargingSessionViewModel
    @State private var selectedSession: ChargingSession?
    @State private var showingSessionDetail = false
    @State private var sessionToDelete: ChargingSession?
    @State private var showingDeleteAlert = false
    
    private func selectSession(_ session: ChargingSession) {
        print("DEBUG: selectSession called with session date: \(session.formattedDate)")
        selectedSession = session
        showingSessionDetail = true
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.sessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            print("DEBUG: Row tapped for session: \(session.formattedDate)")
                            selectSession(session)
                        }
                        .swipeActions(edge: .leading) {
                            Button(role: .destructive) {
                                sessionToDelete = session
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing) {
                            Button(session.isPaid ? "Mark Unpaid" : "Mark Paid") {
                                viewModel.togglePaidStatus(for: session)
                            }
                            .tint(session.isPaid ? .red : .green)
                        }
                }
            }
            .navigationTitle(Text(LocalizedStringKey("EV Charging Payment")))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingSessionDetail) {
                NavigationView {
                    if let session = selectedSession {
                        SessionDetailView(session: session, viewModel: viewModel)
                    }
                }
            }
            .onChange(of: showingSessionDetail) { newValue in
                print("DEBUG: showingSessionDetail changed to: \(newValue)")
            }
            .onChange(of: selectedSession) { newValue in
                print("DEBUG: selectedSession changed to: \(newValue?.formattedDate ?? "nil")")
            }
            .alert(Text("Delete Session"), isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let session = sessionToDelete {
                        viewModel.deleteSession(session)
                    }
                }
            } message: {
                Text("Are you sure you want to delete this session? This action cannot be undone.")
            }
        }
        .onAppear {
            print("DEBUG: SessionsView appeared")
            viewModel.fetchSessions()
        }
        .localized()
    }
}

struct SessionRow: View {
    @ObservedObject var session: ChargingSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.formattedDate)
                    .font(.headline)
                Spacer()
                Text(session.formattedKWh)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Group {
                    if session.isPaid {
                        Label("Paid", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Unpaid", systemImage: "circle")
                            .foregroundColor(.orange)
                    }
                }
                .font(.subheadline)
                .fontWeight(.medium)
                
                Spacer()
                Text(session.formattedCost)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

struct SessionDetailView: View {
    let session: ChargingSession
    @ObservedObject var viewModel: ChargingSessionViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var notes: String
    @State private var isEditingNotes = false
    @State private var showingShareSheet = false
    @State private var showingCameraHandler = false
    @State private var showingPhotoOptions = false
    @State private var selectedImage: UIImage?
    
    init(session: ChargingSession, viewModel: ChargingSessionViewModel) {
        self.session = session
        self.viewModel = viewModel
        _notes = State(initialValue: session.notes ?? "")
        if let photoURL = session.photoURL {
            _selectedImage = State(initialValue: UIImage(contentsOfFile: photoURL.path))
        }
    }
    
    var shareMessage: String {
        var message = """
        \(NSLocalizedString("EV Charging Session", comment: "")) - \(session.formattedDateForSharing)
        \(NSLocalizedString("Previous Reading:", comment: "")) \(Int(session.previousReading)) \(NSLocalizedString("kWh", comment: ""))
        \(NSLocalizedString("New Reading:", comment: "")) \(Int(session.newReading)) \(NSLocalizedString("kWh", comment: ""))
        \(NSLocalizedString("Energy Used:", comment: "")) \(session.formattedKWh)
        \(NSLocalizedString("Cost:", comment: "")) **\(session.formattedCost)**
        \(NSLocalizedString("Status:", comment: "")) **\(NSLocalizedString(session.isPaid ? "Paid" : "Unpaid", comment: ""))**
        """
        
        if let notes = session.notes, !notes.isEmpty {
            message += "\n\(NSLocalizedString("Notes:", comment: "")) \(notes)"
        }
        
        return message
    }
    
    var shareItems: [Any] {
        var items: [Any] = [shareMessage]
        if let photoURL = session.photoURL,
           let image = UIImage(contentsOfFile: photoURL.path) {
            items.append(image)
        }
        return items
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date and Time
                Text(session.formattedDate)
                    .font(.title2)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                // Meter Readings
                VStack(spacing: 10) {
                    HStack {
                        Text(LocalizedStringKey("Previous Reading:"))
                        Spacer()
                        Text(String(format: "%.0f kWh", session.previousReading))
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("New Reading:"))
                        Spacer()
                        Text(String(format: "%.0f kWh", session.newReading))
                            .fontWeight(.medium)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text(LocalizedStringKey("Energy Used:"))
                        Spacer()
                        Text(session.formattedKWh)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text(LocalizedStringKey("Cost:"))
                        Spacer()
                        Text(session.formattedCost)
                            .fontWeight(.bold)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Payment Status with Toggle
                VStack(spacing: 10) {
                    HStack {
                        Text(LocalizedStringKey("Status:"))
                        Spacer()
                        Button(action: {
                            viewModel.togglePaidStatus(for: session)
                        }) {
                            HStack {
                                Image(systemName: session.isPaid ? "checkmark.circle.fill" : "circle")
                                Text(LocalizedStringKey(session.isPaid ? "Paid" : "Unpaid"))
                            }
                            .foregroundColor(session.isPaid ? .green : .orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Photo Section with Management Options
                VStack(spacing: 15) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(10)
                            .overlay(
                                Button(action: { showingPhotoOptions = true }) {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.7))
                                        .clipShape(Circle())
                                }
                                .padding(8),
                                alignment: .topTrailing
                            )
                    } else {
                        Button(action: { showingCameraHandler = true }) {
                            VStack {
                                Image(systemName: "camera")
                                    .font(.largeTitle)
                                    .padding()
                                Text(LocalizedStringKey("Add Meter Photo"))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                        }
                    }
                }
                .confirmationDialog(LocalizedStringKey("Photo Options"), isPresented: $showingPhotoOptions) {
                    Button(LocalizedStringKey("Replace Photo")) {
                        showingCameraHandler = true
                    }
                    Button(LocalizedStringKey("Remove Photo"), role: .destructive) {
                        viewModel.removePhoto(from: session)
                        selectedImage = nil
                    }
                    Button(LocalizedStringKey("Cancel"), role: .cancel) { }
                }
                
                // Notes
                VStack(alignment: .leading) {
                    HStack {
                        Text(LocalizedStringKey("Notes"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                        Button(action: { isEditingNotes.toggle() }) {
                            Text(LocalizedStringKey(isEditingNotes ? "Done" : "Edit"))
                        }
                    }
                    
                    if isEditingNotes {
                        TextEditor(text: $notes)
                            .frame(height: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .onChange(of: notes) { _ in
                                viewModel.updateNotes(for: session, notes: notes)
                            }
                    } else {
                        Text(LocalizedStringKey(notes.isEmpty ? "No notes" : notes))
                            .foregroundColor(notes.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                // Share Button
                Button(action: {
                    showingShareSheet = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(LocalizedStringKey("Share Session Details"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitle(LocalizedStringKey("Session Details"), displayMode: .inline)
        .navigationBarItems(trailing: Button("Done") {
            presentationMode.wrappedValue.dismiss()
        })
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        .sheet(isPresented: $showingCameraHandler) {
            CameraHandler(selectedImage: $selectedImage)
                .onDisappear {
                    if let image = selectedImage {
                        if let url = saveImage(image) {
                            viewModel.updatePhoto(for: session, url: url)
                        }
                    }
                }
        }
        .onAppear {
            #if DEBUG
            print("DEBUG: SessionDetailView appeared with session: \(session.formattedDate)")
            #endif
        }
    }
    
    private func saveImage(_ image: UIImage) -> URL? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let filename = UUID().uuidString + ".jpg"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            viewModel.errorMessage = "Failed to save image: \(error.localizedDescription)"
            return nil
        }
    }
}

// ShareSheet wrapper for UIActivityViewController
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 