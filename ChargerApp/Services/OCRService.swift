import Vision
import UIKit

class OCRService {
    enum OCRError: Error {
        case invalidImage
        case noTextFound
        case processingError(String)
        case noValidReading
        
        var localizedDescription: String {
            switch self {
            case .invalidImage:
                return "Invalid image format"
            case .noTextFound:
                return "No text found in image"
            case .processingError(let message):
                return "Processing error: \(message)"
            case .noValidReading:
                return "No valid meter reading found"
            }
        }
    }
    
    typealias OCRCompletion = (Result<[String], OCRError>) -> Void
    typealias MeterReadingCompletion = (Result<Double, OCRError>) -> Void
    
    static func extractText(from image: UIImage, completion: @escaping OCRCompletion) {
        print("📷 Starting OCR text extraction")
        print("Input image size: \(image.size), scale: \(image.scale), orientation: \(image.imageOrientation.rawValue)")
        
        guard let cgImage = image.cgImage else {
            print("❌ Failed to get CGImage from UIImage")
            completion(.failure(.invalidImage))
            return
        }
        
        print("CGImage size: \(cgImage.width)x\(cgImage.height)")
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("❌ VNRecognizeTextRequest failed: \(error.localizedDescription)")
                completion(.failure(.processingError(error.localizedDescription)))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("❌ No text observations found")
                completion(.failure(.noTextFound))
                return
            }
            
            print("📝 Found \(observations.count) text observations")
            
            let recognizedStrings = observations.compactMap { observation -> String? in
                guard let topCandidate = observation.topCandidates(1).first else { return nil }
                print("Found text: '\(topCandidate.string)' with confidence: \(topCandidate.confidence)")
                return topCandidate.string
            }
            
            if recognizedStrings.isEmpty {
                print("❌ No strings extracted from observations")
                completion(.failure(.noTextFound))
            } else {
                print("✅ Successfully extracted \(recognizedStrings.count) strings")
                completion(.success(recognizedStrings))
            }
        }
        
        // Configure the recognition request
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        print("🔍 Performing OCR with recognition level: \(request.recognitionLevel.rawValue)")
        
        do {
            try requestHandler.perform([request])
        } catch {
            print("❌ OCR request handler failed: \(error.localizedDescription)")
            completion(.failure(.processingError(error.localizedDescription)))
        }
    }
    
    static func extractNumbers(from image: UIImage, completion: @escaping (Result<[Double], OCRError>) -> Void) {
        print("🔢 Starting number extraction")
        
        extractText(from: image) { result in
            switch result {
            case .success(let strings):
                print("Processing \(strings.count) strings for number extraction")
                // Process strings to extract numbers
                let numbers = strings.compactMap { string -> [Double]? in
                    // Regular expression to match numbers (including decimals)
                    let pattern = #"[-+]?\d*\.?\d+"#
                    let regex = try? NSRegularExpression(pattern: pattern)
                    let range = NSRange(string.startIndex..., in: string)
                    
                    guard let regex = regex else {
                        print("❌ Failed to create regex pattern")
                        return nil
                    }
                    
                    let matches = regex.matches(in: string, range: range)
                    print("Found \(matches.count) number matches in string: '\(string)'")
                    
                    return matches.compactMap { match -> Double? in
                        let matchedString = String(string[Range(match.range, in: string)!])
                        print("Attempting to convert '\(matchedString)' to Double")
                        return Double(matchedString)
                    }
                }.flatMap { $0 }
                
                print("Extracted numbers: \(numbers)")
                
                if numbers.isEmpty {
                    print("❌ No numbers found in text")
                    completion(.failure(.noTextFound))
                } else {
                    completion(.success(numbers))
                }
                
            case .failure(let error):
                print("❌ Text extraction failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    static func extractNumbersAsString(from image: UIImage, completion: @escaping (Result<String, OCRError>) -> Void) {
        extractNumbers(from: image) { result in
            switch result {
            case .success(let numbers):
                let formattedString = numbers
                    .map { String(format: "%.2f", $0) }
                    .joined(separator: ", ")
                completion(.success("Meter Reading: \(formattedString)"))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    static func extractMeterReading(from image: UIImage, completion: @escaping MeterReadingCompletion) {
        print("📊 Starting meter reading extraction")
        
        extractNumbers(from: image) { result in
            switch result {
            case .success(let numbers):
                print("Processing \(numbers.count) numbers for meter reading")
                // Sort numbers by length and value to find the most likely meter reading
                let sortedNumbers = numbers.sorted { (a, b) -> Bool in
                    // Prefer longer numbers (more digits)
                    let aStr = String(format: "%.0f", a)
                    let bStr = String(format: "%.0f", b)
                    if aStr.count != bStr.count {
                        return aStr.count > bStr.count
                    }
                    // If same length, prefer larger numbers
                    return a > b
                }
                
                print("Sorted numbers: \(sortedNumbers)")
                
                if let mostLikelyReading = sortedNumbers.first {
                    print("✅ Selected meter reading: \(mostLikelyReading)")
                    completion(.success(mostLikelyReading))
                } else {
                    print("❌ No valid meter reading found")
                    completion(.failure(.noValidReading))
                }
                
            case .failure(let error):
                print("❌ Number extraction failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
} 