import Foundation

internal struct JWT {
    internal let header: [String: Any]
    internal let payload: [String: Any]
    internal let signature: String
    internal let claims: [String: Any]

    internal init?(jwtString: String) {
        // Split the JWT into its three parts: header, payload, and signature
        let jwtParts = jwtString.components(separatedBy: ".")

        guard jwtParts.count == 3 else {
            // Invalid JWT format
            return nil
        }

        // Decode and parse the header
        guard let headerData = jwtParts[0].base64UrlDecodedData(),
              let header = try? JSONSerialization.jsonObject(with: headerData, options: []) as? [String: Any] else {
            // Error decoding header
            return nil
        }

        // Decode and parse the payload
        guard let payloadData = jwtParts[1].base64UrlDecodedData(),
              let payload = try? JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any] else {
            // Error decoding payload
            return nil
        }

        // Extract the signature
        let signature = jwtParts[2]

        let claims = payload

        self.header = header
        self.payload = payload
        self.signature = signature
        self.claims = claims
    }

    internal func getClaim<T>(_ name: String, as type: T.Type) -> T? {
        return claims[name] as? T
    }
}

internal extension JWT {
    private enum Constants {
        // By default, a session will be considered unauthenticated 60 seconds prior
        // to its token's expiration time. This is so we can eagerly re-authenticate
        // before the server would reject requests with a 401.
        static let DEFAULT_EXPIRATION_THRESHOLD_SECONDS: Double = 60
    }

    func isExpired() -> Bool {
        guard let authExpiration = self.getExpiration() else {
            return true
        }

        let expiration = (authExpiration - Constants.DEFAULT_EXPIRATION_THRESHOLD_SECONDS) * 1000
        let currentTime = Date().timeIntervalSince1970 * 1000
        return currentTime >= expiration
    }

    func getExpiration() -> Double? {
        return self.getClaim("exp", as: Double.self)
    }
}

internal extension String {
    func asJwt() -> JWT? {
        return JWT(jwtString: self)
    }
}
