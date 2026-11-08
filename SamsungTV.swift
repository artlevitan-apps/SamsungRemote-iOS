import Foundation
import Network

@MainActor
final class SamsungTV: ObservableObject {
    @Published var ip = UserDefaults.standard.string(forKey: "tvIP") ?? "192.168.0.101"
    @Published var status = "Не подключено"
    @Published var connected = false
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var token = UserDefaults.standard.string(forKey: "tvToken") ?? ""

    func connect() {
        disconnect()
        let host = ip.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, !host.contains("/"), !host.contains(":"),
              host.split(separator: ".").count == 4 else {
            status = "Введите IPv4-адрес телевизора"
            return
        }
        UserDefaults.standard.set(host, forKey: "tvIP")
        let name = Data("iPhone Remote".utf8).base64EncodedString()
        var url = URLComponents()
        url.scheme = "wss"
        url.host = host
        url.port = 8002
        url.path = "/api/v2/channels/samsung.remote.control"
        url.queryItems = [URLQueryItem(name: "name", value: name)]
        if !token.isEmpty { url.queryItems?.append(URLQueryItem(name: "token", value: token)) }
        guard let endpoint = url.url else { status = "Неверный адрес"; return }
        // Samsung TVs often use a self-signed certificate on port 8002.
        session = URLSession(configuration: .default, delegate: TVCertificateDelegate(expectedHost: host), delegateQueue: nil)
        socket = session?.webSocketTask(with: endpoint)
        status = "Подключаемся — подтвердите доступ на ТВ"
        socket?.resume()
        receive()
    }

    func disconnect() {
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
        session?.invalidateAndCancel()
        session = nil
        connected = false
    }

    private func receive() {
        guard let socket else { return }
        socket.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.socket === socket else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message,
                       let data = text.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        let event = json["event"] as? String ?? ""
                        if event == "ms.channel.connect" {
                            if let body = json["data"] as? [String: Any],
                               let newToken = body["token"] as? String {
                                self.token = newToken
                                UserDefaults.standard.set(newToken, forKey: "tvToken")
                            }
                            self.connected = true
                            self.status = "Подключено"
                        } else if event == "ms.channel.unauthorized" {
                            self.status = "Доступ отклонён на телевизоре"
                            self.connected = false
                        }
                    }
                    self.receive()
                case .failure(let error):
                    self.connected = false
                    self.status = "Ошибка соединения: \(error.localizedDescription)"
                }
            }
        }
    }

    func key(_ code: String) {
        guard connected, let socket else { return }
        let payload: [String: Any] = [
            "method": "ms.remote.control",
            "params": ["Cmd": "Click", "DataOfCmd": code, "Option": "false", "TypeOfRemote": "SendRemoteKey"]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let string = String(data: data, encoding: .utf8) else { return }
        socket.send(.string(string)) { [weak self] error in
            if let error {
                Task { @MainActor [weak self] in self?.status = "Ошибка команды: \(error.localizedDescription)" }
            }
        }
    }
}

// Accept a self-signed certificate ONLY for the explicitly entered local TV host.
// This is appropriate for a personal LAN prototype, not a general-purpose TLS policy.
private final class TVCertificateDelegate: NSObject, URLSessionDelegate {
    let expectedHost: String
    init(expectedHost: String) { self.expectedHost = expectedHost }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              challenge.protectionSpace.host == expectedHost,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
