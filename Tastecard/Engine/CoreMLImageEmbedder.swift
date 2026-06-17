//
//  CoreMLImageEmbedder.swift
//  Tastecard
//
//  The on-device SigLIP image encoder (§6). Quantised .mlpackage produced by
//  scripts/convert_siglip_coreml.py and added to the app target (Xcode compiles it to
//  SigLIPImageEncoder.mlmodelc). The convert script BAKES SigLIP preprocessing
//  (resize + normalise) into the model, so this side just hands over the image.
//
//  The model input is an image feature named "image"; the output is an MLMultiArray
//  named "embedding". If the model is absent (e.g. before you run the convert script),
//  init throws .modelMissing and the app shows a setup state instead of crashing.
//

import CoreML
import CoreGraphics
import Foundation

final class CoreMLImageEmbedder: ImageEmbedder {

    let dimension: Int
    let inputSide: Int

    private let model: MLModel
    private let inputName: String
    private let outputName: String
    private let imageConstraint: MLImageConstraint

    init(modelName: String = "SigLIPImageEncoder",
         inputName: String = "image",
         outputName: String = "embedding",
         bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: modelName, withExtension: "mlmodelc") else {
            throw EmbedderError.modelMissing
        }
        let config = MLModelConfiguration()
        config.computeUnits = .all   // Neural Engine + GPU + CPU
        do {
            self.model = try MLModel(contentsOf: url, configuration: config)
        } catch {
            throw EmbedderError.modelLoadFailed(String(describing: error))
        }

        self.inputName = inputName
        self.outputName = outputName

        let desc = model.modelDescription
        guard let imageConstraint = desc.inputDescriptionsByName[inputName]?.imageConstraint else {
            throw EmbedderError.modelLoadFailed("input '\(inputName)' is not an image feature")
        }
        self.imageConstraint = imageConstraint
        self.inputSide = imageConstraint.pixelsWide

        // Determine the output embedding dimension from the model description.
        // The encoder outputs [1, D] (or [D]); the batch dim is 1, so the total element
        // count equals the embedding dimension.
        guard let shape = desc.outputDescriptionsByName[outputName]?.multiArrayConstraint?.shape else {
            throw EmbedderError.modelLoadFailed("output '\(outputName)' is not a multiarray feature")
        }
        let total = shape.map(\.intValue).reduce(1, *)
        guard total > 0 else { throw EmbedderError.modelLoadFailed("output has no elements") }
        self.dimension = total
    }

    func embed(_ image: CGImage) throws -> [Float] {
        let featureValue: MLFeatureValue
        do {
            featureValue = try MLFeatureValue(cgImage: image, constraint: imageConstraint, options: nil)
        } catch {
            throw EmbedderError.inferenceFailed("image preprocessing: \(error)")
        }

        let provider: MLFeatureProvider
        do {
            provider = try MLDictionaryFeatureProvider(dictionary: [inputName: featureValue])
            let output = try model.prediction(from: provider)
            guard let multi = output.featureValue(for: outputName)?.multiArrayValue else {
                throw EmbedderError.inferenceFailed("missing output '\(outputName)'")
            }
            return VectorMath.l2Normalized(Self.floats(from: multi))
        } catch let e as EmbedderError {
            throw e
        } catch {
            throw EmbedderError.inferenceFailed(String(describing: error))
        }
    }

    private static func floats(from multi: MLMultiArray) -> [Float] {
        let count = multi.count
        var out = [Float](repeating: 0, count: count)
        switch multi.dataType {
        case .float32:
            let ptr = multi.dataPointer.bindMemory(to: Float32.self, capacity: count)
            for i in 0..<count { out[i] = ptr[i] }
        case .double:
            let ptr = multi.dataPointer.bindMemory(to: Double.self, capacity: count)
            for i in 0..<count { out[i] = Float(ptr[i]) }
        case .float16:
            // Read element-wise via NSNumber to avoid Float16 ABI assumptions.
            for i in 0..<count { out[i] = multi[i].floatValue }
        @unknown default:
            for i in 0..<count { out[i] = multi[i].floatValue }
        }
        return out
    }
}
