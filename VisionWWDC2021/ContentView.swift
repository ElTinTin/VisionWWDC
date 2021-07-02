//
//  ContentView.swift
//  VisionWWDC2021
//
//  Created by Quentin Deschamps on 14/06/2021.
//

import SwiftUI
import Foundation
import CoreImage
import Vision
import CoreML
import CoreImage
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    
    @State var originalImage: Image?
    @State var correctedImage: Image?
    @State var extractedText: String?

    func perspectiveCorrectedImage(from ciImage: CIImage, rectangleObservation: VNRectangleObservation) -> CIImage? {
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        originalImage = convertImage(ciImage: ciImage)
        
        // Perform pespective correction
        let width = Int(cgImage.width)
        let height = Int(cgImage.height)
        guard let filter = CIFilter(name:"CIPerspectiveCorrection")  else { return nil }
        
        filter.setValue(CIImage(cgImage: cgImage), forKey: "inputImage")
        filter.setValue(CIVector(cgPoint: VNImagePointForNormalizedPoint(rectangleObservation.topLeft, width, height)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: VNImagePointForNormalizedPoint(rectangleObservation.topRight, width, height)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: VNImagePointForNormalizedPoint(rectangleObservation.bottomLeft, width, height)), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: VNImagePointForNormalizedPoint(rectangleObservation.bottomRight, width, height)), forKey: "inputBottomRight")
        
        guard
            let outputCIImage = filter.outputImage,
            let outputCGImage = CIContext(options: nil).createCGImage(outputCIImage, from: outputCIImage.extent)  else {return nil}
        
        correctedImage = convertImage(ciImage: outputCIImage)
        
        return CIImage(cgImage: outputCGImage)
    }
    
    func convertImage(ciImage: CIImage) -> Image? {
        let context = CIContext()
        let currentFilter = CIFilter.sepiaTone()
        currentFilter.inputImage = ciImage
        currentFilter.intensity = 1
        
        guard let outputImage = currentFilter.outputImage else { return nil }
        if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
            
            let uiImage = UIImage(cgImage: cgimg)
            
            return Image(uiImage: uiImage).resizable()
        } else {
            return nil
        }
    }
    
    func getDocument() {
        guard let inputImage = CIImage(contentsOf: #fileLiteral(resourceName: "ReceiptSwiss.jpg")) else { fatalError("image not found") }

        let requestHandler = VNImageRequestHandler(ciImage: inputImage)
        let documentDetectionRequest = VNDetectDocumentSegmentationRequest()
        do {
            try requestHandler.perform([documentDetectionRequest]) }
        catch {
            print(error)
        }

        guard let document = documentDetectionRequest.results?.first,
              let documentImage = perspectiveCorrectedImage(from: inputImage, rectangleObservation: document) else {
                  fatalError("Unable to get document image.")
              }

        let documentRequestHandler = VNImageRequestHandler(ciImage: documentImage)

        var textBlocks: [VNRecognizedTextObservation] = []

        let ocrRequest = VNRecognizeTextRequest { request, error in
            textBlocks = request.results as! [VNRecognizedTextObservation]
        }
        
        do {
            try documentRequestHandler.perform([ocrRequest])
        } catch {
            print(error)
        }
        
        var stringResults : [String] = []
        
        for results in textBlocks {
            guard let result = results.topCandidates(1).first else { return }
            print(result.string)
        }
        
        for string in stringResults {
            if extractedText != nil {
                extractedText = "\(String(describing: extractedText)) + \(string)"
            } else {
                extractedText = "\(string)"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack {
                    Button("Scan!") {
                        getDocument()
                    }
                }
                VStack {
                    originalImage
                        .scaledToFit()
                    correctedImage
                        .scaledToFit()
                    HStack {
                        Text("Texte extrait de l'image : \(extractedText ?? "")")
                    }
                }
            }
            .padding()
        }
    }
}
