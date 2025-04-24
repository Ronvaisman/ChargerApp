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
            Group {
                if viewModel.sessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text(LocalizedStringKey("No Charging Sessions"))
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text(LocalizedStringKey("Your charging history will appear here"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
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