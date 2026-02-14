public protocol MetricSampler {
    associatedtype Sample

    func sample() throws -> Sample
}
