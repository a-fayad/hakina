import SwiftUI
import Vision
import UIKit
import PhotosUI

struct ContentView: View {
    @State private var recognizedText: String = ""
    @State private var translatedText: String = ""
    @State private var isLoading = false
    @State private var hasRun = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    var body: some View {
        VStack(spacing: 16) {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
            } else {
                ContentUnavailableView("No photo selected", systemImage: "photo")
                    .frame(height: 250)
            }

            PhotosPicker("Choose Photo", selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }

            Button("Recognize & Translate") {
                recognizeAndTranslate()
            }
            .padding()
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || selectedImage == nil)

            if isLoading {
                ProgressView("Working...")
            }

            if hasRun && !isLoading {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recognized text:")
                                .font(.headline)
                            Text(recognizedText.isEmpty ? "(none found)" : recognizedText)
                                .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Translation:")
                                .font(.headline)
                            Text(translatedText)
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
    }

    func recognizeAndTranslate() {
        guard let uiImage = selectedImage,
              let cgImage = uiImage.cgImage else {
            recognizedText = "Could not load image"
            hasRun = true
            return
        }

        isLoading = true

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasRun = true
                }
                return
            }

            let strings = observations.compactMap { $0.topCandidates(1).first?.string }
            let fullText = strings.joined(separator: " ")

            DispatchQueue.main.async {
                self.recognizedText = fullText
            }

            if fullText.isEmpty {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.hasRun = true
                }
                return
            }

            // Chain into Gemini translation
            GeminiTranslator.translate(fullText) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let translation):
                        self.translatedText = translation
                    case .failure(let error):
                        self.translatedText = "Error: \(error.localizedDescription)"
                    }
                    self.isLoading = false
                    self.hasRun = true
                }
            }
        }

        request.recognitionLevel = VNRequestTextRecognitionLevel.accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ar"]  

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

#Preview {
    ContentView()
}
