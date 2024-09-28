import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authModel: AuthModel
    @Binding var isShowingSignUp: Bool
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var birthDate = Date()
    @State private var gender = "male"
    
    private var isSignUpDisabled: Bool {
        authModel.userData.nombre.isEmpty ||
        authModel.userData.email.isEmpty ||
        authModel.userData.celular.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        password != confirmPassword
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Crear cuenta")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField("Nombre", text: $authModel.userData.nombre)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(true)
                    
                    TextField("Celular", text: $authModel.userData.celular)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.phonePad)
                    
                    TextField("Email", text: $authModel.userData.email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .textInputAutocapitalization(.never)
                    
                    Picker("Género", selection: $gender) {
                        Text("Male").tag("male")
                        Text("Female").tag("female")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    DatePicker("Fecha de Nacimiento", selection: $birthDate, displayedComponents: .date)
                }
                .padding(.horizontal)
                
                Button(action: {
                    Task {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateFormat = "yyyy-MM-dd"
                        authModel.userData.fechaDeNacimiento = dateFormatter.string(from: birthDate)
                        authModel.userData.genero = gender
                        await authModel.signUp(password: password)
                    }
                }) {
                    Text("Sign Up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSignUpDisabled ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isSignUpDisabled)
                .padding(.horizontal)
                
                Button(action: {
                    isShowingSignUp = false
                }) {
                    Text("¿Ya tienes una cuenta? Inicia sesión")
                        .foregroundColor(.blue)
                        .underline()
                }
                .padding(.top, 10)
                
                Text("OR")
                    .fontWeight(.bold)
                    .foregroundColor(.gray)
                    .padding()
                
                Button(action: {
                    Task {
                        await authModel.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .foregroundColor(.black)
                        Text("Continuar con Google")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
                }
                .padding(.horizontal)
                
                if case .error(let errorMessage) = authModel.authState {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            }
            .padding()
            .disabled(authModel.isLoading)
            .overlay(
                Group {
                    if authModel.isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }
}

#Preview {
    SignUpView(isShowingSignUp: .constant(true))
        .environmentObject(AuthModel())
}
