import SwiftUI
import UIKit

struct ImageEditorView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImageCropViewController {
        let controller = UIImageCropViewController(image: image ?? UIImage())
        controller.delegate = context.coordinator
        controller.aspectRatioPreset = .presetFree
        controller.aspectRatioLockEnabled = false
        controller.rotateButtonsHidden = false
        controller.rotateClockwiseButtonHidden = false
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImageCropViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImageCropViewControllerDelegate {
        let parent: ImageEditorView
        
        init(_ parent: ImageEditorView) {
            self.parent = parent
        }
        
        func cropViewController(_ cropViewController: UIImageCropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int) {
            parent.image = image
            parent.dismiss()
        }
        
        func cropViewControllerDidCancel(_ cropViewController: UIImageCropViewController) {
            parent.dismiss()
        }
    }
}

class UIImageCropViewController: UIViewController {
    private let imageView: UIImageView
    private let cropOverlay: UIView
    private var initialImage: UIImage
    weak var delegate: UIImageCropViewControllerDelegate?
    var aspectRatioPreset: AspectRatioPreset = .presetFree
    var aspectRatioLockEnabled = false
    var rotateButtonsHidden = false
    var rotateClockwiseButtonHidden = false
    private var currentRotation: CGFloat = 0
    
    enum AspectRatioPreset {
        case presetFree
        case presetSquare
        case preset3x2
        case preset5x4
        case preset4x3
        case preset5x3
        case preset16x9
    }
    
    init(image: UIImage) {
        self.initialImage = image
        self.imageView = UIImageView(image: image)
        self.cropOverlay = UIView()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        // Setup crop overlay
        cropOverlay.backgroundColor = .clear
        cropOverlay.layer.borderColor = UIColor.white.cgColor
        cropOverlay.layer.borderWidth = 1
        cropOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropOverlay)
        
        // Setup buttons
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .equalSpacing
        buttonStack.spacing = 20
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let rotateButton = UIButton(type: .system)
        rotateButton.setImage(UIImage(systemName: "rotate.right"), for: .normal)
        rotateButton.addTarget(self, action: #selector(rotateTapped), for: .touchUpInside)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(rotateButton)
        buttonStack.addArrangedSubview(doneButton)
        
        view.addSubview(buttonStack)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -20),
            
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            cropOverlay.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            cropOverlay.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            cropOverlay.widthAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: 0.8),
            cropOverlay.heightAnchor.constraint(equalTo: cropOverlay.widthAnchor, multiplier: 0.5)
        ])
        
        // Setup gestures
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        cropOverlay.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        cropOverlay.addGestureRecognizer(pinchGesture)
    }
    
    @objc private func cancelTapped() {
        delegate?.cropViewControllerDidCancel(self)
    }
    
    @objc private func rotateTapped() {
        currentRotation += .pi/2
        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = CGAffineTransform(rotationAngle: self.currentRotation)
        }
    }
    
    @objc private func doneTapped() {
        // Get the cropped image based on the overlay position
        let scale = imageView.frame.width / initialImage.size.width
        let cropRect = cropOverlay.frame.applying(CGAffineTransform(scaleX: 1/scale, y: 1/scale))
        
        let renderer = UIGraphicsImageRenderer(size: cropRect.size)
        let croppedImage = renderer.image { context in
            let drawRect = CGRect(origin: .zero, size: cropRect.size)
            context.cgContext.translateBy(x: -cropRect.minX, y: -cropRect.minY)
            initialImage.draw(in: CGRect(origin: .zero, size: initialImage.size))
        }
        
        delegate?.cropViewController(self, didCropToImage: croppedImage, withRect: cropRect, angle: Int(currentRotation * 180 / .pi))
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        if gesture.state == .changed {
            cropOverlay.center = CGPoint(
                x: cropOverlay.center.x + translation.x,
                y: cropOverlay.center.y + translation.y
            )
            gesture.setTranslation(.zero, in: view)
        }
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .changed {
            let scale = gesture.scale
            cropOverlay.transform = cropOverlay.transform.scaledBy(x: scale, y: scale)
            gesture.scale = 1.0
        }
    }
}

protocol UIImageCropViewControllerDelegate: AnyObject {
    func cropViewController(_ cropViewController: UIImageCropViewController, didCropToImage image: UIImage, withRect cropRect: CGRect, angle: Int)
    func cropViewControllerDidCancel(_ cropViewController: UIImageCropViewController)
} 