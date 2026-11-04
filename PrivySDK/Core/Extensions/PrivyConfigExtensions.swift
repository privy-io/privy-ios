internal extension PrivyConfig {
    var baseUrl: String {
        if appId.isInternalAppId() {
            // Only using staging env for sdk demo test app
            "https://auth.staging.privy.io"
        } else {
            "https://auth.privy.io"
        }
    }

    func getEmbeddedWalletURL(caid: String) -> String {
        var url = "\(baseUrl)/apps/\(appId)/embedded-wallets?caid=\(caid)"

        if let clientId = appClientId {
            url += "&client_id=\(clientId)"
        }

        return url
    }
}
