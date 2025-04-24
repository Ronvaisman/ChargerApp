import SwiftUI

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
    @State private var ocrResults: String?
    
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
        
        if let ocrText = ocrResults {
            message += "\n\(NSLocalizedString("OCR Reading:", comment: "")) \(ocrText)"
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
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                            .foregroundColor(session.isPaid ? .green : .orange)
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
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
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
                    if let image = selectedImage {
                        OCRService.extractNumbersAsString(from: image) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let text):
                                    self.ocrResults = text
                                case .failure:
                                    self.ocrResults = nil
                                }
                                self.showingShareSheet = true
                            }
                        }
                    } else {
                        self.showingShareSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text(LocalizedStringKey("Share Session Details"))
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity, alignment: .center)
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
            if let image = selectedImage {
                OCRService.extractNumbersAsString(from: image) { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let text):
                            self.ocrResults = text
                        case .failure:
                            self.ocrResults = nil
                        }
                    }
                }
            }
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