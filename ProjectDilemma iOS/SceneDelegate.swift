import UIKit

extension Notification.Name {
    static let gameShouldPause  = Notification.Name("gameShouldPause")
    static let gameShouldResume = Notification.Name("gameShouldResume")
}

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: .gameShouldResume, object: nil)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        NotificationCenter.default.post(name: .gameShouldPause, object: nil)
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
    }
}
