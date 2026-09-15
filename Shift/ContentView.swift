import SwiftUI
import SceneKit

struct ContentView: View {
    // On initialise notre scène 3D (qui sera gérée dans une classe à part)
    var scene = GameScene()
    
    var body: some View {
        ZStack {
            // La vue 3D qui prend tout l'écran
            // Remplace ta SceneView actuelle par celle-ci
            SceneView(
                scene: scene,
                options: [.autoenablesDefaultLighting]
            )
            .ignoresSafeArea()
            .gesture(
                // On détecte un glissement du doigt
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onEnded { value in
                        // On analyse la translation horizontale (width)
                        if value.translation.width < 0 {
                            // Swipe vers la gauche
                            scene.movePlayer(direction: -1)
                        } else if value.translation.width > 0 {
                            // Swipe vers la droite
                            scene.movePlayer(direction: 1)
                        }
                    }
            )
        }
    }
}
