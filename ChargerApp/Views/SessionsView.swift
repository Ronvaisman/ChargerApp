import SwiftUI

struct SessionsView: View {
    @ObservedObject var viewModel: ChargingSessionViewModel
    @State private var selectedSession: ChargingSession?
    @State private var showingSessionDetail = false
    @State private var sessionToDelete: ChargingSession?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.sessions) { session in
                    SessionRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedSession = session
                            showingSessionDetail = true
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
            .navigationTitle(Text("Sessions"))
            .sheet(isPresented: $showingSessionDetail) {
                if let session = selectedSession {
                    SessionDetailView(session: session, viewModel: viewModel)
                }
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
    
    init(session: ChargingSession, viewModel: ChargingSessionViewModel) {
        self.session = session
        self.viewModel = viewModel
        _notes = State(initialValue: session.notes ?? "")
    }
    
    var shareMessage: String {
        """
        \(NSLocalizedString("EV Charging Session", comment: "")) - \(session.formattedDate)
        \(NSLocalizedString("Previous Reading:", comment: "")) \(Int(session.previousReading)) \(NSLocalizedString("kWh", comment: ""))
        \(NSLocalizedString("New Reading:", comment: "")) \(Int(session.newReading)) \(NSLocalizedString("kWh", comment: ""))
        \(NSLocalizedString("Energy Used:", comment: "")) \(session.formattedKWh)
        \(NSLocalizedString("Cost:", comment: "")) \(session.formattedCost)
        \(NSLocalizedString("Status:", comment: "")) \(NSLocalizedString(session.isPaid ? "Paid" : "Unpaid", comment: ""))
        """
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
        NavigationView {
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
                    
                    // Payment Status
                    HStack {
                        Text(LocalizedStringKey("Status:"))
                        Spacer()
                        Text(LocalizedStringKey(session.isPaid ? "Paid" : "Unpaid"))
                            .foregroundColor(session.isPaid ? .green : .orange)
                            .fontWeight(.medium)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // Photo if exists
                    if let photoURL = session.photoURL,
                       let uiImage = UIImage(contentsOfFile: photoURL.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .cornerRadius(10)
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
                            Text("Share Session Details")
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
            .navigationBarTitle("Session Details", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: shareItems)
            }
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