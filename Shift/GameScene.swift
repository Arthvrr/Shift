import SceneKit

struct CollisionCategory {
    static let player = 1 << 0   // Identifiant 1
    static let obstacle = 1 << 1 // Identifiant 2
}

class GameScene: SCNScene {
    
    var onGameOver: (() -> Void)?
    
    // Le cube qui représentera notre joueur pour le moment
    var playerNode: SCNNode!
    
    // Les coordonnées X strictes de nos 4 bandes
    let lanes: [Float] = [-0.9, -0.3, 0.3, 0.9]
    var currentLaneIndex = 1 // On commence sur la bande centrale gauche
    
    override init() {
        super.init()
        setupCamera()
        setupPlayer()
        setupEnvironment()
        //spawnObstacle()
        
        startSpawning()
        
        self.physicsWorld.contactDelegate = self
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
        let geometry = SCNBox(width: 0.4, height: 0.4, length: 0.8, chamferRadius: 0.05)
        geometry.firstMaterial?.diffuse.contents = UIColor.systemRed
        
        playerNode = SCNNode(geometry: geometry)
        
        // On le place sur la bande de départ
        playerNode.position = SCNVector3(x: lanes[currentLaneIndex], y: 0.2, z: 0)
        
        // On donne un corps physique au joueur
        playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        
        // On lui colle l'étiquette "player"
        playerNode.physicsBody?.categoryBitMask = CollisionCategory.player
        
        // On demande à être prévenu s'il touche l'étiquette "obstacle"
        playerNode.physicsBody?.contactTestBitMask = CollisionCategory.obstacle
        
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
    
    func setupEnvironment() {
        // 1. Le ciel (fond de la scène)
        self.background.contents = UIColor.systemTeal // Un bleu ciel clair
        
        // 2. La route (un sol infini)
        let floorGeometry = SCNFloor()
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
        
        let floorNode = SCNNode(geometry: floorGeometry)
        // On le place à Y = 0 (sous le joueur)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.rootNode.addChildNode(floorNode)
    }
    
    func spawnObstacle() {
        // On choisit une des 4 bandes au hasard
        guard let randomLane = lanes.randomElement() else { return }
        
        // On crée l'ennemi (un cube gris clair)
        let obstacleGeo = SCNBox(width: 0.4, height: 0.4, length: 0.8, chamferRadius: 0.05)
        obstacleGeo.firstMaterial?.diffuse.contents = UIColor.lightGray
        let obstacleNode = SCNNode(geometry: obstacleGeo)
        
        // L'astuce : on le place très loin devant le joueur (Z = -50)
        obstacleNode.position = SCNVector3(x: randomLane, y: 0.2, z: -50)
        
        // On donne un corps physique à l'obstacle
        obstacleNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: nil)
        
        // On lui colle l'étiquette "obstacle"
        obstacleNode.physicsBody?.categoryBitMask = CollisionCategory.obstacle
        
        self.rootNode.addChildNode(obstacleNode)
        
        // On crée l'animation : avancer de 60 mètres vers nous (vers Z positif) en 2 secondes
        let moveAction = SCNAction.moveBy(x: 0, y: 0, z: 60, duration: 2.0)
        
        // TRÈS IMPORTANT : On supprime le nœud une fois qu'il est passé derrière la caméra
        // Sinon, la mémoire de l'iPhone va saturer après quelques minutes de jeu !
        let removeAction = SCNAction.removeFromParentNode()
        
        // On exécute l'action d'avancer, puis celle de disparaître
        let sequence = SCNAction.sequence([moveAction, removeAction])
        obstacleNode.runAction(sequence)
    }
    
    func startSpawning() {
        // 1. Action d'attente (1 seconde entre chaque voiture)
        let wait = SCNAction.wait(duration: 1.0)
        
        // 2. Action qui exécute la fonction d'apparition que tu as créée juste avant
        let spawn = SCNAction.run { _ in
            self.spawnObstacle()
        }
        
        // 3. On combine dans une séquence : Attendre -> Apparaître
        let sequence = SCNAction.sequence([wait, spawn])
        
        // 4. On crée une action qui répète cette séquence à l'infini
        let repeatForever = SCNAction.repeatForever(sequence)
        
        // 5. On lance la boucle (on lui donne un nom "spawningLoop" pour pouvoir l'arrêter lors d'un Game Over)
        self.rootNode.runAction(repeatForever, forKey: "spawningLoop")
    }
    
}

extension GameScene: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        //print("💥 BOOM ! Collision détectée !")
        self.rootNode.removeAction(forKey: "spawningLoop")
        self.isPaused = true
        
        // On envoie le signal à SwiftUI sur le fil principal
        DispatchQueue.main.async {
            self.onGameOver?()
        }
    }
}
