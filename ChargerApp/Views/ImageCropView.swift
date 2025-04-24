import SwiftUI
import UIKit

struct ImageCropView: View {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cropRect: CGRect = .zero
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(LocalizedStringKey("Select Meter Reading Area"))
                    .font(.headline)
                    .padding()
                
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        scale *= delta
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                    
                    // Crop rectangle overlay
                    CropRectangle(rect: $cropRect)
                }
                .frame(maxWidth: .infinity, maxHeight: geometry.size.height * 0.7)
                .clipped()
                
                HStack(spacing: 20) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text(LocalizedStringKey("Cancel"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        cropImage()
                        dismiss()
                    }) {
                        Text(LocalizedStringKey("Crop"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            // Initialize crop rectangle to a reasonable default size
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let imageSize = image.size
                let screenSize = UIScreen.main.bounds.size
                let scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                
                // Make crop rectangle about 1/3 of the image height
                cropRect = CGRect(
                    x: scaledWidth * 0.25,
                    y: scaledHeight * 0.4,
                    width: scaledWidth * 0.5,
                    height: scaledHeight * 0.2
                )
            }
        }
    }
    
    private func cropImage() {
        print("🔍 Starting image crop process")
        print("Original image size: \(image.size), scale: \(image.scale), orientation: \(image.imageOrientation.rawValue)")
        
        // Calculate the actual image frame in the view
        let imageSize = image.size
        let screenSize = UIScreen.main.bounds.size
        let viewScale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
        let scaledImageSize = CGSize(
            width: imageSize.width * viewScale,
            height: imageSize.height * viewScale
        )
        
        print("Screen size: \(screenSize)")
        print("View scale: \(viewScale)")
        print("Scaled image size: \(scaledImageSize)")
        print("Current crop rect: \(cropRect)")
        
        // Calculate the crop rectangle in the actual image coordinates
        let scaleTransform = CGAffineTransform(scaleX: imageSize.width / scaledImageSize.width,
                                              y: imageSize.height / scaledImageSize.height)
        let cropRectInImage = cropRect.applying(scaleTransform)
        
        print("Scale transform: \(scaleTransform)")
        print("Crop rect in image coordinates: \(cropRectInImage)")
        
        // Create a new image context with the crop size
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: cropRectInImage.size, format: format)
        
        print("Creating renderer with size: \(cropRectInImage.size) and scale: \(format.scale)")
        
        let croppedImage = renderer.image { context in
            // Calculate the source rect in the original image
            let drawRect = CGRect(origin: .zero, size: cropRectInImage.size)
            
            // Create the destination rect
            let sourceRect = CGRect(
                x: cropRectInImage.minX,
                y: cropRectInImage.minY,
                width: cropRectInImage.width,
                height: cropRectInImage.height
            )
            
            print("Draw rect: \(drawRect)")
            print("Source rect: \(sourceRect)")
            
            // Draw the cropped portion
            image.draw(in: drawRect, blendMode: .normal, alpha: 1.0)
            
            // Clip to the crop rect
            context.cgContext.clip(to: drawRect)
            
            // Draw the image
            if let cgImage = image.cgImage?.cropping(to: sourceRect) {
                print("Successfully created cropped CGImage")
                let croppedUIImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                croppedUIImage.draw(in: drawRect)
            } else {
                print("❌ Failed to create cropped CGImage")
            }
        }
        
        print("Final cropped image size: \(croppedImage.size), scale: \(croppedImage.scale)")
        self.croppedImage = croppedImage
    }
}

struct CropRectangle: View {
    @Binding var rect: CGRect
    @State private var draggedCorner: Corner?
    @GestureState private var dragState = CGSize.zero
    
    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(
                                    width: rect.width,
                                    height: rect.height
                                )
                                .position(
                                    x: rect.origin.x + rect.width / 2,
                                    y: rect.origin.y + rect.height / 2
                                )
                                .blendMode(.destinationOut)
                        )
                )
            
            // Crop rectangle outline
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.origin.x + rect.width / 2, y: rect.origin.y + rect.height / 2)
            
            // Corner handles
            ForEach(Corner.allCases, id: \.self) { corner in
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .position(position(for: corner))
                    .gesture(
                        DragGesture()
                            .updating($dragState) { value, state, _ in
                                state = value.translation
                            }
                            .onChanged { _ in
                                draggedCorner = corner
                            }
                            .onEnded { value in
                                updateRect(for: corner, with: value.translation)
                                draggedCorner = nil
                            }
                    )
            }
        }
    }
    
    private func position(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight:
            return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft:
            return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight:
            return CGPoint(x: rect.maxX, y: rect.maxY)
        }
    }
    
    private func updateRect(for corner: Corner, with translation: CGSize) {
        var newRect = rect
        
        switch corner {
        case .topLeft:
            newRect.origin.x += translation.width
            newRect.origin.y += translation.height
            newRect.size.width -= translation.width
            newRect.size.height -= translation.height
        case .topRight:
            newRect.origin.y += translation.height
            newRect.size.width += translation.width
            newRect.size.height -= translation.height
        case .bottomLeft:
            newRect.origin.x += translation.width
            newRect.size.width -= translation.width
            newRect.size.height += translation.height
        case .bottomRight:
            newRect.size.width += translation.width
            newRect.size.height += translation.height
        }
        
        // Ensure minimum size
        if newRect.size.width >= 50 && newRect.size.height >= 50 {
            rect = newRect
        }
    }
} 