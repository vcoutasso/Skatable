//
//  LoginViewController.swift
//  Skatable
//
//  Created by Vinícius Couto on 04/09/21.
//

import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseFirestore
import UIKit

class LoginViewController: UIViewController {
    // Unhashed nonce.
    fileprivate var currentNonce: String?

    let skelly: UIImageView = .init()
    let textLabel: UILabel = .init()
    let appleButton: ASAuthorizationAppleIDButton = .init(type: .continue, style: .white)

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupHierarchy()
        setupConstraints()
    }

    private func setupViews() {
        skelly.image = UIImage(asset: Assets.Images.loginSkelly)
        skelly.translatesAutoresizingMaskIntoConstraints = false

        textLabel.text = "PARÇA, É NOIX.\nPRONTO PRO ROLÊ?"
        textLabel.textAlignment = .center
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.numberOfLines = 0
        textLabel.font = UIFont(font: Fonts.SpriteGraffiti.regular, size: 40)

        appleButton.translatesAutoresizingMaskIntoConstraints = false
        appleButton.cornerRadius = 13
        appleButton.addTarget(self, action: #selector(startSignInWithAppleFlow), for: .touchUpInside)
    }

    func setupHierarchy() {
        view.addSubview(textLabel)
        view.addSubview(skelly)
        view.addSubview(appleButton)
    }

    func setupConstraints() {
        skelly.snp.makeConstraints { make in
            make.topMargin.equalToSuperview().offset(20)
            make.centerXWithinMargins.equalToSuperview()
        }
        textLabel.snp.makeConstraints { make in
            make.centerXWithinMargins.equalToSuperview()
            make.topMargin.equalTo(skelly.snp.bottomMargin)
            make.bottomMargin.equalTo(appleButton.snp.topMargin).offset(-20)
        }
        appleButton.snp.makeConstraints { make in
            make.topMargin.equalTo(textLabel.snp.bottomMargin).offset(20)
            make.bottomMargin.equalToSuperview().offset(-40)
            make.leftMargin.equalToSuperview().offset(45)
            make.rightMargin.equalToSuperview().offset(-45)
            make.centerXWithinMargins.equalToSuperview()
        }
    }

    @available(iOS 13, *)
    @objc func startSignInWithAppleFlow() {
        let nonce = randomNonceString()
        currentNonce = nonce
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()

        return hashString
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            randoms.forEach { random in
                if length == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }
}

@available(iOS 13.0, *)
extension LoginViewController: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            let credential = OAuthProvider.credential(
                withProviderID: "apple.com",
                idToken: idTokenString,
                rawNonce: nonce
            )
            Auth.auth().signIn(with: credential) { authResult, error in
                if error != nil {
                    // Error. If error.code == .MissingOrInvalidNonce, make sure
                    // you're sending the SHA256-hashed nonce as a hex string with
                    // your request to Apple.
                    print(error?.localizedDescription ?? "")
                    return
                }
                guard let user = authResult?.user else { return }
                let email = user.email ?? ""
                guard let uid = Auth.auth().currentUser?.uid else { return }
                let db = Firestore.firestore()
                db.collection("User").document(uid).setData([
                    "email": email,
                    "uid": uid,
                ]) { err in
                    if let err = err {
                        print("Error writing document: \(err)")
                    }
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // Handle error.
        print("Sign in with Apple errored: \(error)")
    }
}

extension LoginViewController: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return view.window!
    }
}
