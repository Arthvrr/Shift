import SceneKit

class GameScene: SCNScene {
    
    // Le cube qui représentera notre joueur pour le moment
    var playerNode: SCNNode!
    
    // Les coordonnées X strictes de nos 4 bandes
    let lanes: [Float] = [-1.5, -0.5, 0.5, 1.5]
    var currentLaneIndex = 1 // On commence sur la bande centrale gauche
    
    override init() {
        super.init()
        setupCamera()
        setupPlayer()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // On place la caméra en hauteur et reculée (axe Z)
        cameraNode.position = SCNVector3(x: 0, y: 3, z: 5)
        // On l'incline légèrement vers le bas
        cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 8, y: 0, z: 0)
        self.rootNode.addChildNode(cameraNode)
    }
    
    func setupPlayer() {
        // Un simple cube rouge pour commencer
        let geometry = SCNBox(width: 0.8, height: 0.8, length: 1.5, chamferRadius: 0.1)
        geometry.firstMaterial?.diffuse.contents = UIColor.systemRed
        
        playerNode = SCNNode(geometry: geometry)
        
        // On le place sur la bande de départ
        playerNode.position = SCNVector3(x: lanes[currentLaneIndex], y: 0.4, z: 0)
        self.rootNode.addChildNode(playerNode)
    }
    
    func movePlayer(direction: Int) {
        // direction: -1 pour la gauche, 1 pour la droite
        let newIndex = currentLaneIndex + direction
        
        // On vérifie qu'on reste dans les limites des 4 bandes (index de 0 à 3)
        if newIndex >= 0 && newIndex < lanes.count {
            currentLaneIndex = newIndex
            
            // On récupère la coordonnée X de la nouvelle bande
            let targetX = lanes[currentLaneIndex]
            
            // CORRECTION SCENEKIT : On crée un vecteur 3D avec le nouveau X, et on garde les Y et Z actuels
            let targetPosition = SCNVector3(
                x: targetX,
                y: playerNode.position.y,
                z: playerNode.position.z
            )
            
            // On utilise la bonne méthode 3D : move(to:duration:)
            let moveAction = SCNAction.move(to: targetPosition, duration: 0.15)
            moveAction.timingMode = .easeOut // Rend le mouvement plus naturel (décélère à la fin)
            
            // On fait exécuter l'action à notre joueur
            playerNode.runAction(moveAction)
        }
    }
    
}
