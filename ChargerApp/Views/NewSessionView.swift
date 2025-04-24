import SwiftUI

struct ImageButton: View {
    let action: () -> Void
    let content: AnyView
    let color: Color
    let width: CGFloat
    let imageName: String
    let height: CGFloat
    
    init(color: Color, width: CGFloat = UIScreen.main.bounds.width * 0.45, height: CGFloat = 120, imageName: String? = nil, action: @escaping () -> Void, @ViewBuilder content: () -> some View) {
        self.color = color
        self.width = width
        self.height = height
        self.action = action
        self.content = AnyView(content())
        if let name = imageName {
            self.imageName = name
        } else {
            self.imageName = color == .green ? "ButtonGreen" : "ButtonBlue"
        }
    }
    
    var body: some View {
        Button(action: action) {
            buttonContent
        }
    }
    
    private var buttonContent: some View {
        ZStack {
            buttonBackground
            buttonLabel
        }
        .frame(height: height)
    }
    
    private var buttonBackground: some View {
        Image(imageName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: width, height: height)
    }
    
    private var buttonLabel: some View {
        content
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
    }
}

struct NewSessionView: View {
    @ObservedObject var viewModel: ChargingSessionViewModel
    @State private var newReading: String = ""
    @State private var previousReadingInput: String = ""
    @State private var showingCamera = false
    @State private var showingImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showingCalculation = false
    @State private var calculatedKwh: Double = 0
    @State private var calculatedCost: Double = 0
    @State private var showingFullScreenPhoto = false
    @State private var showingSaveConfirmation = false
    @State private var isValidationError = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case previousReading
        case newReading
    }
    
    private var shouldShowPreviousReadingInput: Bool {
        return viewModel.sessions.isEmpty
    }
    
    private var previousReading: Double {
        if viewModel.sessions.isEmpty {
            if !previousReadingInput.isEmpty {
                let value = Double(previousReadingInput.replacingOccurrences(of: ",", with: "")) ?? 0
                return value
            }
            return 0
        }
        return viewModel.sessions.first?.newReading ?? 0
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 30) {
                        headerSection
                        meterReadingsSection
                        buttonSection
                        if showingCalculation { calculationSection }
                        photoInstructionText
                        if let image = selectedImage {
                            photoPreviewSection(image)
                        }
                    }
                    .padding(.vertical, 30)
                }
                .onTapGesture {
                    focusedField = nil // This will dismiss the keyboard
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: focusedField) { _ in
                validateInputs()
            }
            .alert(item: Binding(
                get: { viewModel.errorMessage.map { ErrorWrapper(error: $0, isError: $0.contains("Error") || $0.contains("Failed")) } },
                set: { _ in viewModel.errorMessage = nil }
            )) { errorWrapper in
                Alert(
                    title: Text(errorWrapper.isError ? "Error" : "Success"),
                    message: Text(errorWrapper.error),
                    dismissButton: .default(Text("OK"))
                )
            }
            .overlay {
                if showingSaveConfirmation {
                    SaveConfirmationBanner()
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera, showingImagePicker: $showingImagePicker)
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPicker(image: $selectedImage)
        }
    }
    
    private var headerSection: some View {
        Text("Zap-n-Tap")
            .font(.title)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
    }
    
    private var meterReadingsSection: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Previous Meter")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    
                    if shouldShowPreviousReadingInput {
                        TextField("0", text: $previousReadingInput)
                            .font(.system(size: 34, weight: .regular))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .previousReading)
                            .frame(height: 60)
                            .background(Color(white: 0.15))
                            .cornerRadius(12)
                    } else {
                        Text(String(format: "%.0f", previousReading))
                            .font(.system(size: 34, weight: .regular))
                            .foregroundColor(.white)
                            .frame(height: 60)
                            .frame(maxWidth: .infinity)
                            .background(Color(white: 0.15))
                            .cornerRadius(12)
                    }
                }
                .frame(maxWidth: .infinity)
                
                VStack(spacing: 8) {
                    Text("New Meter")
                        .font(.system(size: 17))
                        .foregroundColor(.white)
                    
                    TextField("", text: $newReading)
                        .font(.system(size: 34, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .newReading)
                        .frame(height: 60)
                        .background(Color(white: 0.15))
                        .cornerRadius(12)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            
            Text("Session kWh = (New Meter - Previous Meter) × 0,402")
                .font(.system(size: 15))
                .foregroundColor(Color(white: 0.6))
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 12) {
            // Calculate Button
            Button(action: calculateUsage) {
                Text("Calculate")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
            }
            
            // Add Photo Button
            Button(action: {
                if selectedImage != nil {
                    selectedImage = nil
                }
                showingCamera = true
            }) {
                HStack {
                    Image(systemName: "camera")
                        .font(.system(size: 20))
                    Text("Add Photo")
                        .font(.system(size: 20, weight: .medium))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue, lineWidth: 2)
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var photoInstructionText: some View {
        Text("Take a clear photo of your meter reading")
            .font(.system(size: 15))
            .foregroundColor(Color(white: 0.6))
    }
    
    private var calculationSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text(String(format: "₪%.2f", calculatedCost))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding()
            
            saveButton
        }
    }
    
    private func photoPreviewSection(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                Button(action: {
                    selectedImage = nil
                    showingCamera = true
                }) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                }
                .padding(8),
                alignment: .topTrailing
            )
            .padding(.horizontal)
            .onTapGesture {
                showingFullScreenPhoto = true
            }
    }
    
    private var saveButton: some View {
        Button(action: saveSession) {
            ZStack {
                Circle()
                    .fill(Color(red: 76/255, green: 175/255, blue: 80/255))
                    .frame(width: 120, height: 120)
                    .shadow(color: Color(red: 76/255, green: 175/255, blue: 80/255).opacity(0.3), radius: 10, x: 0, y: 5)
                
                VStack(spacing: 8) {
                    Image(systemName: "square.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .overlay(
                            Rectangle()
                                .frame(width: 20, height: 15)
                                .foregroundColor(Color(red: 76/255, green: 175/255, blue: 80/255))
                                .offset(y: -8),
                            alignment: .top
                        )
                    Text("SAVE")
                        .font(.system(size: 24, weight: .bold))
                }
                .foregroundColor(.white)
            }
        }
        .disabled(!showingCalculation)
    }
    
    private func validateInputs() {
        guard !newReading.isEmpty && (shouldShowPreviousReadingInput ? !previousReadingInput.isEmpty : true) else { return }
        
        let newValue = Double(newReading.replacingOccurrences(of: ",", with: "")) ?? 0
        if newValue <= previousReading {
            withAnimation(.default) {
                isValidationError = true
                viewModel.errorMessage = "New reading must be higher than previous reading"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isValidationError = false
            }
        }
    }
    
    private func calculateUsage() {
        let cleanNewReading = newReading.replacingOccurrences(of: ",", with: "")
        guard let newReadingValue = Double(cleanNewReading) else {
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
        let cleanNewReading = newReading.replacingOccurrences(of: ",", with: "")
        guard let newReadingValue = Double(cleanNewReading) else { return }
        
        var photoURL: URL?
        if let image = selectedImage {
            photoURL = saveImage(image)
        }
        
        viewModel.createSession(
            previousReading: previousReading,
            newReading: newReadingValue,
            photoURL: photoURL
        )
        
        withAnimation {
            showingSaveConfirmation = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingSaveConfirmation = false
            }
            newReading = ""
            previousReadingInput = ""
            selectedImage = nil
            showingCalculation = false
        }
        
        // Trigger success haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
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

// MARK: - Supporting Views

struct SaveConfirmationBanner: View {
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Session saved to history")
                    .font(.subheadline.bold())
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 4)
            .padding(.bottom, 32)
        }
        .transition(.move(edge: .bottom))
    }
}

// MARK: - View Modifiers

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

extension View {
    func shake(_ trigger: Bool) -> some View {
        modifier(ShakeModifier(trigger: trigger))
    }
}

struct ShakeModifier: ViewModifier {
    let trigger: Bool
    
    func body(content: Content) -> some View {
        content
            .modifier(ShakeEffect(animatableData: trigger ? 1 : 0))
    }
}

// Helper for showing errors
struct ErrorWrapper: Identifiable {
    let id = UUID()
    let error: String
    let isError: Bool
}

struct GlossyButtonStyle: ViewModifier {
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .frame(width: 200)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Base layer with gradient
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    color,
                                    color.opacity(0.8)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Inner border
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    
                    // Outer border
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(color.opacity(0.5), lineWidth: 1)
                    
                    // Shine effect
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.0)
                                ]),
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
    }
}

extension View {
    func glossyButton(color: Color) -> some View {
        self.modifier(GlossyButtonStyle(color: color))
    }
} 