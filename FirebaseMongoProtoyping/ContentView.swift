import SwiftUI

struct ContentView: View {
    @StateObject private var authModel = AuthModel()
    
    var body: some View {
        AuthenticationView()
    }
}


#Preview {
    ContentView()
        .environmentObject(AuthModel())
}
