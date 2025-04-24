import SwiftUI
import Vision
import VisionKit

struct OCRScannerView: View {
    @State private var showingImagePicker = false
    @State private var showingScanner = false
    @State private var selectedImage: UIImage?
    @State private var recognizedNumbers: [Double] = []
    @State private var errorMessage: String?
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .padding()
                }
                
                if !recognizedNumbers.isEmpty {
                    List(recognizedNumbers, id: \.self) { number in
                        Text(String(format: "%.2f", number))
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                }
                
                HStack {
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        Label("Choose Photo", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    if VNDocumentCameraViewController.isSupported {
                        Button(action: {
                            showingScanner = true
                        }) {
                            Label("Scan Document", systemImage: "doc.text.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Number Scanner")
            .sheet(isPresented: $showingImagePicker) {
                OCRImagePicker(image: $selectedImage, sourceType: .photoLibrary)
            }
            .sheet(isPresented: $showingScanner) {
                ScannerView(selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) { _ in
                processImage()
            }
        }
    }
    
    private func processImage() {
        guard let image = selectedImage else { return }
        isProcessing = true
        errorMessage = nil
        
        OCRService.extractNumbers(from: image) { result in
            DispatchQueue.main.async {
                isProcessing = false
                switch result {
                case .success(let numbers):
                    self.recognizedNumbers = numbers
                    if numbers.isEmpty {
                        self.errorMessage = "No numbers found in image"
                    }
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.recognizedNumbers = []
                }
            }
        }
    }
}

struct OCRImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: OCRImagePicker
        
        init(_ parent: OCRImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            picker.dismiss(animated: true)
        }
    }
}

struct ScannerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = context.coordinator
        return scannerViewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScannerView
        
        init(_ parent: ScannerView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.selectedImage = scan.imageOfPage(at: 0)
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scanner failed with error: \(error.localizedDescription)")
            controller.dismiss(animated: true)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
    }
} 