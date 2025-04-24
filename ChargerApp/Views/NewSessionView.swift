import SwiftUI

struct NewSessionView: View {
    @ObservedObject var viewModel: ChargingSessionViewModel
    @State private var newReading: String = ""
    @State private var showingCameraHandler = false
    @State private var selectedImage: UIImage?
    @State private var showingCalculation = false
    @State private var calculatedKwh: Double = 0
    @State private var calculatedCost: Double = 0
    
    private var previousReading: Double {
        viewModel.sessions.first?.newReading ?? 0
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    Text("Electricity Usage & Payment")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    // Meter readings section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Previous Meter")
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(previousReading))")
                                .font(.system(size: 32, weight: .bold))
                                .frame(width: 120, alignment: .center)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            
                            Spacer()
                            
                            TextField("New Reading", text: $newReading)
                                .font(.system(size: 32, weight: .bold))
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 120)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                        }
                        .padding(.horizontal)
                        
                        Text("Session kWh = (New Meter - Previous Meter) × 0.402")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    
                    // Calculate Button
                    Button(action: calculateUsage) {
                        Text("Calculate")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    if showingCalculation {
                        VStack(spacing: 10) {
                            Text("Amount to Pay")
                                .font(.headline)
                            Text(String(format: "₪%.2f", calculatedCost))
                                .font(.system(size: 28, weight: .bold))
                        }
                        .padding()
                    }
                    
                    // Photo section
                    VStack(spacing: 15) {
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(10)
                                .overlay(
                                    Button(action: { selectedImage = nil }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.7))
                                            .clipShape(Circle())
                                    }
                                    .padding(8),
                                    alignment: .topTrailing
                                )
                        }
                        
                        Button(action: { showingCameraHandler = true }) {
                            HStack {
                                Image(systemName: selectedImage == nil ? "camera" : "arrow.counterclockwise")
                                Text(selectedImage == nil ? "Add Meter Photo" : "Retake Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        if selectedImage == nil {
                            Text("Take a clear photo of your meter reading")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Save Button
                    Button(action: saveSession) {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(!showingCalculation)
                }
                .padding(.vertical)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCameraHandler) {
            CameraHandler(selectedImage: $selectedImage)
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage.map { ErrorWrapper(error: $0) } },
            set: { _ in viewModel.errorMessage = nil }
        )) { errorWrapper in
            Alert(
                title: Text("Error"),
                message: Text(errorWrapper.error),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func calculateUsage() {
        guard let newReadingValue = Double(newReading) else {
            viewModel.errorMessage = "Please enter a valid number"
            return
        }
        
        if let calculation = viewModel.calculateUsage(
            previousReading: previousReading,
            newReading: newReadingValue
        ) {
            calculatedKwh = calculation.kwhUsed
            calculatedCost = calculation.cost
            showingCalculation = true
        }
    }
    
    private func saveSession() {
        guard let newReadingValue = Double(newReading) else { return }
        
        // Save image if exists
        var photoURL: URL?
        if let image = selectedImage {
            photoURL = saveImage(image)
        }
        
        viewModel.createSession(
            previousReading: previousReading,
            newReading: newReadingValue,
            photoURL: photoURL
        )
        
        // Reset form
        newReading = ""
        selectedImage = nil
        showingCalculation = false
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

// Helper for showing errors
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
} 