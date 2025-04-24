import SwiftUI
import PhotosUI
import AVFoundation

struct CameraHandler: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    // Preview of selected/captured image
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(10)
                        .padding()
                    
                    // Retake/Choose Different Photo button
                    Button(action: {
                        selectedImage = nil
                    }) {
                        Label("Retake Photo", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                } else {
                    // Camera and Photo Library buttons
                    VStack(spacing: 20) {
                        Button(action: {
                            checkCameraPermission()
                        }) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                Text("Take Photo")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        Button(action: {
                            sourceType = .photoLibrary
                            showingImagePicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.title2)
                                Text("Choose from Library")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
                    // Instructions
                    VStack(spacing: 10) {
                        Text("Take a clear photo of your meter reading")
                            .font(.headline)
                        Text("Make sure the numbers are clearly visible and well-lit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Meter Photo")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: selectedImage != nil ? Button("Use Photo") {
                    presentationMode.wrappedValue.dismiss()
                } : nil
            )
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage, sourceType: sourceType)
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
        } message: {
            Text("Please allow camera access in Settings to take photos of your meter readings.")
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            sourceType = .camera
            showingImagePicker = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        sourceType = .camera
                        showingImagePicker = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 