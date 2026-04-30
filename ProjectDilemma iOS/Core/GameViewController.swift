// GameViewController.swift
/*
 Author: Cameron Ridgley
 Worked on this caude while having claude in help with the methods and strutures from time to time
 Also having claude fix bugs when necessary
 */

import UIKit
import SpriteKit

final class GameViewController: UIViewController, GameScenePresenter {

    private var skView: SKView!
    private var hasStartedGame = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSKView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        
        guard !hasStartedGame, view.bounds.size != .zero else { return }
        hasStartedGame = true

        GameManager.shared.scenePresenter = self
        GameManager.shared.sceneSize = view.bounds.size
        GameManager.shared.transition(to: .mainMenu)
    }

    //DEBUG STUFF
    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true

        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsPhysics = false
        #endif

        view.addSubview(skView)
    }

 

    func present(scene: SKScene) {
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
    }

    

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }
}
