internal actor CompletionHandlerStore {
    private var completionHandlers = [String: CompletionHandlerHolder]()

    internal func set(_ handler: CompletionHandlerHolder, forId id: String) {
        completionHandlers[id] = handler
    }

    internal func getAndRemove(forId id: String) -> CompletionHandlerHolder? {
        let temp = completionHandlers[id]
        completionHandlers[id] = nil
        return temp
    }

    internal func remove(id: String) {
        completionHandlers[id] = nil
    }

    internal func clearAllWithError() {
        let handlers = completionHandlers.values
        completionHandlers.removeAll()

        // Invoke all pending handlers with process termination error
        for handler in handlers {
            handler.completion("{\"error\":\"WebView process terminated by system\"}")
        }
    }
}

internal struct CompletionHandlerHolder: Sendable {
    internal let completion: @Sendable (String) -> Void
}
