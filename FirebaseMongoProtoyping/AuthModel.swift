import SwiftUI
import FirebaseCore
import FirebaseAuth
import GoogleSignIn
import os

struct UserData: Codable {
    var name: String = ""
    var phone: String = ""
    var email: String = ""
}

class AuthModel: ObservableObject {
    enum AuthState {
        case signedOut
        case signingIn
        case needsPhoneNumber
        case authenticating
        case authenticated
        case error(String)
    }
    
    @Published var authState: AuthState = .signedOut
    @Published var userData = UserData()
    @Published var isLoading = false
    
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AuthModel")
    private let baseURL = "http://127.0.0.1:4000/api"
    
    init() {
        checkUserSession()
    }
    
    func checkUserSession() {
        logger.info("Checking user session")
        if Auth.auth().currentUser != nil {
            authState = .authenticated
            Task {
                await fetchUserInfo()
            }
        } else {
            authState = .signedOut
        }
    }
    
    @MainActor
    func signUp(password: String) async {
        logger.info("Starting sign up process")
        authState = .signingIn
        isLoading = true
        do {
            try await Auth.auth().createUser(withEmail: userData.email, password: password)
            try await sendUserInfo()
            try await initiateEmailVerification()
            await fetchUserInfo()
            authState = .authenticated
            logger.info("Sign up successful")
        } catch {
            logger.error("Sign up failed: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
        isLoading = false
    }
    
    @MainActor
    func login(email: String, password: String) async {
        logger.info("Starting login process")
        authState = .signingIn
        isLoading = true
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
            await fetchUserInfo()
            authState = .authenticated
            logger.info("Login successful")
        } catch {
            logger.error("Login failed: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
        isLoading = false
    }
    
    @MainActor
    func signInWithGoogle() async {
        logger.info("Starting Google Sign-In process")
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            authState = .error("Failed to get Google client ID")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            authState = .error("Failed to get root view controller")
            return
        }
        
        do {
            authState = .signingIn
            isLoading = true
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token from Google"])
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            _ = try await Auth.auth().signIn(with: credential)
            
            // Attempt to fetch existing user data
            let userDataExists = await fetchUserInfo()
            
            if userDataExists {
                // User exists, only update email if it's empty
                if userData.email.isEmpty {
                    userData.email = result.user.profile?.email ?? ""
                    try await sendUserInfo()
                }
                
                if userData.phone.isEmpty {
                    authState = .needsPhoneNumber
                    logger.info("Google Sign-In successful, requesting phone number for existing user")
                } else {
                    authState = .authenticated
                    logger.info("Google Sign-In successful, existing user profile complete")
                }
            } else {
                // New user, use Google data
                userData.name = result.user.profile?.name ?? ""
                userData.email = result.user.profile?.email ?? ""
                authState = .needsPhoneNumber
                logger.info("Google Sign-In successful, requesting phone number for new user")
            }
        } catch {
            logger.error("Google Sign-In failed: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
        isLoading = false
    }
    @MainActor
    func completeUserProfile(phoneNumber: String) async {
        logger.info("Completing user profile with phone number")
        authState = .authenticating
        isLoading = true
        userData.phone = phoneNumber
        do {
            try await sendUserInfo()
            authState = .authenticated
            logger.info("User profile completed successfully")
        } catch {
            logger.error("Failed to complete user profile: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
        isLoading = false
    }
    
    @MainActor
    func logout() async {
        logger.info("Logging out")
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            authState = .signedOut
            userData = UserData()
            logger.info("Logout successful")
        } catch {
            logger.error("Logout failed: \(error.localizedDescription)")
            authState = .error(error.localizedDescription)
        }
    }
    
    private func sendUserInfo() async throws {
        logger.info("Sending user info to server")
        guard let url = URL(string: "\(baseURL)/user") else {
            throw NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(try await Auth.auth().currentUser!.getIDToken())", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(userData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            logger.error("Server responded with an error when sending user info")
            throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server responded with an error when sending user info"])
        }
        
        logger.info("User info sent successfully")
    }
    
    private func initiateEmailVerification() async throws {
        logger.info("Initiating email verification")
        guard let url = URL(string: "\(baseURL)/verifyEmail") else {
            throw NSError(domain: "URLError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(try await Auth.auth().currentUser!.getIDToken())", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            logger.error("Server responded with an error when initiating email verification")
            throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server responded with an error when initiating email verification"])
        }
        
        logger.info("Email verification initiated successfully")
    }
    
    @MainActor
    func fetchUserInfo() async -> Bool {
        logger.info("Fetching user info from server")
        guard let url = URL(string: "\(baseURL)/user") else {
            authState = .error("Invalid URL")
            return false
        }
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.addValue("Bearer \(try await Auth.auth().currentUser!.getIDToken())", forHTTPHeaderField: "Authorization")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid server response"])
            }
            
            if httpResponse.statusCode == 404 {
                // User not found, treat as new user
                logger.info("User not found on server, treating as new user")
                return false
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw NSError(domain: "ServerError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Server responded with an error when fetching user info"])
            }
            
            let fetchedUserData = try JSONDecoder().decode(UserData.self, from: data)
            self.userData = fetchedUserData
            logger.info("User info fetched successfully")
            return true
        } catch {
            logger.error("Failed to fetch user info: \(error.localizedDescription)")
            if (error as NSError).domain == "ServerError" {
                authState = .error(error.localizedDescription)
            } else {
                // If it's not a server error, treat as new user
                logger.info("Treating as new user due to fetch error")
                return false
            }
        }
        return false
    }
    
    func updateUserInfo(newData: [String: Any]) async throws {
        logger.info("Updating user info")
        do {
            // Perform the update on the main thread
            await MainActor.run {
                // Update only the fields that are provided
                if let name = newData["name"] as? String {
                    self.userData.name = name
                }
                if let phone = newData["phone"] as? String {
                    self.userData.phone = phone
                }
                if let email = newData["email"] as? String {
                    self.userData.email = email
                }
            }
            
            // Send the updated user data to the server
            try await sendUserInfo()
            logger.info("User info updated successfully")
        } catch {
            logger.error("Failed to update user info: \(error.localizedDescription)")
            throw error
        }
    }
}
