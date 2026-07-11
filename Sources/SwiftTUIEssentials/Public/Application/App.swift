import Foundation

/// The entry point for a SwiftTUI application.
///
/// Declare one type that conforms to `App` and annotate it with `@main`.
/// SwiftTUI creates the app value, resolves its root scene, starts a terminal
/// session, and runs the render/input loop until termination is requested.
@MainActor
@preconcurrency
public protocol App {

    /// The scene type produced by this app.
    associatedtype Body: Scene

    /// The scene hierarchy that SwiftTUI renders into the terminal.
    @SceneBuilder
    var body: Body { get }

    /// Creates the app instance that `main()` runs.
    init()
}

public extension App {

    /// Starts the SwiftTUI terminal event loop for this app.
    ///
    /// This method is normally invoked by Swift's `@main` entry point. It
    /// configures the terminal session, repeatedly renders the root scene into
    /// the current viewport, dispatches keyboard and pointer input, and prints a
    /// startup error if the terminal session cannot be created.
    static func main() {
        do {
            try AppRunner(app: Self()).run()
        }
        catch {
            TerminalControl.write("SwiftTUI failed to start: \(error)\n")
        }
    }
}
