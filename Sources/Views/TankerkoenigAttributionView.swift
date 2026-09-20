import SwiftUI

/// Pflicht-Attribution für per Tankerkönig-API bezogene Daten (CC BY 4.0) –
/// gemeinsam genutzt von der Umkreissuche und dem Menüleisten-Popover, damit
/// der Text nicht zweimal gepflegt werden muss.
struct TankerkoenigAttributionView: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Preisdaten:")
            Link("Tankerkönig", destination: URL(string: "https://creativecommons.tankerkoenig.de")!)
            Text("(CC BY 4.0)")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
