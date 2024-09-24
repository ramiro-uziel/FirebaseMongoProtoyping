import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authModel: AuthModel
    @State private var isShowingSignUp = false
    @State private var phoneNumber = ""
    
    var body: some View {
        NavigationView {
            VStack {
                switch authModel.authState {
                case .signedOut:
                    if isShowingSignUp {
                        SignUpView(isShowingSignUp: $isShowingSignUp)
                    } else {
                        LoginView(isShowingSignUp: $isShowingSignUp)
                    }
                case .signingIn:
                    ProgressView("Signing in...")
                case .needsPhoneNumber:
                    VStack {
                        Text("Complete Your Profile")
                            .font(.title)
                            .padding()
                        
                        TextField("Phone Number", text: $phoneNumber)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.phonePad)
                            .padding()
                        
                        Button("Complete Profile") {
                            Task {
                                await authModel.completeUserProfile(phoneNumber: phoneNumber)
                            }
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                case .authenticating:
                    ProgressView("Completing profile...")
                case .authenticated:
                    AuthenticatedView()
                case .error(let message):
                    VStack {
                        Text("An error occurred")
                            .font(.title)
                            .foregroundColor(.red)
                        
                        Text(message)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("Try Again") {
                            authModel.authState = .signedOut
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding()
                }
            }
            .onAppear {
                authModel.checkUserSession()
            }
        }
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthModel())
}
