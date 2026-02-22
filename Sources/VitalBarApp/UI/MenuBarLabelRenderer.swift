enum MenuBarLabelRenderer: String, CaseIterable, Identifiable {
    case vector
    case image

    var id: Self { self }

    var title: String {
        switch self {
        case .vector:
            return "Vector"
        case .image:
            return "Image"
        }
    }
}
