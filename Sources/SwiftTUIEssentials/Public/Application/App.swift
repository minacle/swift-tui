import Foundation

/// The entry point for a SwiftTUI application.
///
/// Declare one type that conforms to `App` and annotate it with `@main`.
/// SwiftTUI creates the app value, resolves its root scene, starts a terminal
/// session, and runs the render/input loop until termination is requested.
@MainActor
@preconcurrency
public protocol App {

    /// The concrete scene hierarchy produced by this app.
    ///
    /// SwiftTUI resolves this value once when ``main()`` starts the app.
    associatedtype Body: Scene

    /// The root scene hierarchy for the terminal session.
    ///
    /// Return a ``WindowGroup`` directly or through ``SceneBuilder`` control
    /// flow. SwiftTUI renders the resolved window group's root view into the
    /// current terminal viewport.
    @SceneBuilder
    var body: Body { get }

    /// Creates the app value used to start the terminal session.
    ///
    /// The synthesized `@main` entry point requires this initializer and calls
    /// it once before resolving ``body``.
    init()
}

extension App {

    /// Starts the SwiftTUI terminal event loop for this app.
    ///
    /// This method is normally invoked by Swift's `@main` entry point. It
    /// configures the terminal session, repeatedly renders the root scene into
    /// the current viewport, dispatches keyboard and pointer input, and prints a
    /// startup error if the terminal session cannot be created. Startup errors
    /// are reported to terminal output rather than propagated to the caller.
    public static func main() {
        do {
            try AppRunner(app: Self()).run()
        }
        catch {
            TerminalControl.write("SwiftTUI failed to start: \(error)\n")
        }
    }
}
