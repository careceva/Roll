import SwiftUI

struct FilterView: View {
    @Binding var image: UIImage

    var body: some View {
        Text("Filters are available in the Edit screen")
            .foregroundColor(.secondary)
            .padding()
    }
}

#Preview {
    FilterView(image: .constant(UIImage()))
}
