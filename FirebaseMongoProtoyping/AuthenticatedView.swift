import SwiftUI

struct AuthenticatedView: View {
    @EnvironmentObject var authModel: AuthModel
    @State private var isEditingProfile = false
    @State private var editedName = ""
    @State private var editedPhone = ""
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Information")) {
                    if isEditingProfile {
                        TextField("Name", text: $editedName)
                        TextField("Phone", text: $editedPhone)
                            .keyboardType(.phonePad)
                    } else {
                        LabeledContent("Name", value: authModel.userData.name)
                        LabeledContent("Email", value: authModel.userData.email)
                        LabeledContent("Phone", value: authModel.userData.phone)
                    }
                }
                
                Section {
                    if isEditingProfile {
                        Button("Save Changes") {
                            saveChanges()
                        }
                        .disabled(editedName.isEmpty || editedPhone.isEmpty)
                    } else {
                        Button("Edit Profile") {
                            startEditing()
                        }
                    }
                }
                
                Section {
                    Button("Sign Out") {
                        Task {
                            await authModel.logout()
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Welcome, \(authModel.userData.name)!")
            .toolbar {
                if isEditingProfile {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private func startEditing() {
        editedName = authModel.userData.name
        editedPhone = authModel.userData.phone
        isEditingProfile = true
    }
    
    private func cancelEditing() {
        isEditingProfile = false
    }
    
    private func saveChanges() {
        Task {
            do {
                try await authModel.updateUserInfo(newData: [
                    "name": editedName,
                    "phone": editedPhone
                ])
                await MainActor.run {
                    isEditingProfile = false
                }
            } catch {
                await MainActor.run {
                    showingAlert = true
                    alertMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            }
        }
    }
}

#Preview {
    AuthenticatedView()
        .environmentObject(AuthModel())
}
