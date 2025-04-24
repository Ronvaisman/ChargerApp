import SwiftUI
import PhotosUI
import AVFoundation

struct CameraHandler: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingPermissionAlert = false
    @State private var showingPhotoLibraryPermissionAlert = false
    @State private var showingImageEditor = false
    @State private var sourceType: UIImagePickerController.SourceType = .camera
    @State private var editedImage: UIImage?
    
    private let buttonWidth: CGFloat = 160
    private let buttonHeight: CGFloat = 50
    
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
                    
                    // Edit Photo button
                    Button(action: {
                        showingImageEditor = true
                    }) {
                        Label("Edit", systemImage: "crop")
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // Retake/Choose Different Photo button
                    Button(action: {
                        selectedImage = nil
                    }) {
                        Label("Retake Photo", systemImage: "arrow.counterclockwise")
                            .frame(width: buttonWidth, height: buttonHeight)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                } else {
                    // Camera and Photo Library buttons
                    VStack(spacing: 20) {
                        HStack(spacing: 15) {
                            Button(action: {
                                checkCameraPermission()
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("Take Photo")
                                }
                                .frame(width: buttonWidth, height: buttonHeight)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Button(action: {
                                checkPhotoLibraryPermission()
                            }) {
                                HStack {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.title2)
                                    Text("Choose from Library")
                                }
                                .frame(width: buttonWidth, height: buttonHeight)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
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
            PhotoPicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(image: $selectedImage, sourceType: .camera, showingImagePicker: $showingImagePicker)
        }
        .sheet(isPresented: $showingImageEditor) {
            if let image = selectedImage {
                ImageEditorView(image: $selectedImage)
            }
        }
        .alert("Camera Access Required", isPresented: $showingPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                openSettings()
            }
        } message: {
            Text("Please allow camera access in Settings to take photos of your meter readings.")
        }
        .alert("Photo Library Access Required", isPresented: $showingPhotoLibraryPermissionAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Settings") {
                openSettings()
            }
        } message: {
            Text("Please allow photo library access in Settings to choose photos.")
        }
    }
    
    private func openSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        showingCamera = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }
    
    private func checkPhotoLibraryPermission() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            showingImagePicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        showingImagePicker = true
                    }
                }
            }
        case .denied, .restricted:
            showingPhotoLibraryPermissionAlert = true
        @unknown default:
            break
        }
    }
}

struct PhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker
        
        init(_ parent: PhotoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.parent.image = image as? UIImage
                    }
                }
            }
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) var presentationMode
    @Binding var showingImagePicker: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.showsCameraControls = true
            picker.cameraDevice = .rear
            picker.cameraFlashMode = .auto
            picker.mediaTypes = ["public.image"]
            
            // Add custom overlay view with photo library button
            let overlayView = UIView(frame: picker.view.bounds)
            overlayView.isUserInteractionEnabled = true
            overlayView.backgroundColor = .clear
            
            // Photo Library Button
            let libraryButton = UIButton(type: .system)
            libraryButton.setImage(UIImage(systemName: "photo.on.rectangle")?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 30)), for: .normal)
            libraryButton.tintColor = .white
            libraryButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
            libraryButton.layer.cornerRadius = 35
            libraryButton.isUserInteractionEnabled = true
            
            // Position the button in the top right
            let buttonSize: CGFloat = 70
            let topPadding: CGFloat = 40
            let rightPadding: CGFloat = 20
            
            libraryButton.frame = CGRect(
                x: picker.view.bounds.width - buttonSize - rightPadding,
                y: topPadding,
                width: buttonSize,
                height: buttonSize
            )
            
            libraryButton.addTarget(context.coordinator, action: #selector(Coordinator.switchToPhotoLibrary), for: .touchUpInside)
            
            overlayView.addSubview(libraryButton)
            
            // Make the overlay view ignore touches except for the button
            overlayView.isUserInteractionEnabled = true
            overlayView.frame = CGRect(x: 0, y: 0, width: picker.view.bounds.width, height: 150)
            
            picker.cameraOverlayView = overlayView
        }
        
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
        
        @objc func switchToPhotoLibrary() {
            parent.presentationMode.wrappedValue.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.parent.showingImagePicker = true
            }
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                DispatchQueue.main.async {
                    self.parent.image = image
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 