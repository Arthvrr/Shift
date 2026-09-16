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
    
    var score: Int = 0
    var onScoreUpdate: ((Int) -> Void)?
    
    override init() {
        super.init()
        setupCamera()
        setupPlayer()
        setupEnvironment()
        //spawnObstacle()
        
        prefillLineDashes()
        
        startSpawning()
        startScoring()
        startSpawningLines()
        startSpawningClouds()
        
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
        // 1. Le ciel et le Soleil
        self.background.contents = UIColor.systemTeal
        
        let sunGeo = SCNSphere(radius: 5.0)
        sunGeo.firstMaterial?.diffuse.contents = UIColor.systemYellow
        // L'émission donne l'illusion que l'objet produit de la lumière
        sunGeo.firstMaterial?.emission.contents = UIColor.systemYellow
        
        let sunNode = SCNNode(geometry: sunGeo)
        // Loin (Z = -80), haut (Y = 15), et un peu sur la droite (X = 10)
        sunNode.position = SCNVector3(x: 10, y: 15, z: -80)
        self.rootNode.addChildNode(sunNode)
        
        // 2. L'herbe (Le sol infini devient vert)
        let floorGeometry = SCNFloor()
        floorGeometry.firstMaterial?.diffuse.contents = UIColor.systemGreen
        floorGeometry.reflectivity = 0.0
        let floorNode = SCNNode(geometry: floorGeometry)
        floorNode.position = SCNVector3(x: 0, y: 0, z: 0)
        self.rootNode.addChildNode(floorNode)
        
        // 3. La route en asphalte (par-dessus l'herbe)
        // Largeur totale : de -1.2 à 1.2 = 2.4
        let roadGeo = SCNBox(width: 2.4, height: 0.005, length: 200.0, chamferRadius: 0)
        roadGeo.firstMaterial?.diffuse.contents = UIColor.darkGray
        let roadNode = SCNNode(geometry: roadGeo)
        // On la soulève d'un millimètre (Y=0.005) pour éviter que le gris et le vert ne "clignotent"
        roadNode.position = SCNVector3(x: 0, y: 0.005, z: -45)
        self.rootNode.addChildNode(roadNode)
        
        // 4. Les 2 lignes continues aux extrémités
        let edgeXPositions: [Float] = [-1.2, 1.2]
        for x in edgeXPositions {
            let edgeLineGeo = SCNBox(width: 0.05, height: 0.01, length: 100.0, chamferRadius: 0)
            edgeLineGeo.firstMaterial?.diffuse.contents = UIColor.white
            let edgeLineNode = SCNNode(geometry: edgeLineGeo)
            edgeLineNode.position = SCNVector3(x: x, y: 0.01, z: -45)
            self.rootNode.addChildNode(edgeLineNode)
        }
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
    
    func spawnLineDashes() {
        // Les 3 positions exactes entre tes 4 bandes
        let lineXPositions: [Float] = [-0.6, 0.0, 0.6]
        
        for x in lineXPositions {
            // Un rectangle très fin et plat (width: 0.05, height: tout petit)
            let lineGeo = SCNBox(width: 0.05, height: 0.01, length: 1.0, chamferRadius: 0)
            lineGeo.firstMaterial?.diffuse.contents = UIColor.white
            
            let lineNode = SCNNode(geometry: lineGeo)
            // L'astuce Y = 0.01 : on le place juste un poil au-dessus du sol gris (0.0) pour qu'il soit visible
            lineNode.position = SCNVector3(x: x, y: 0.01, z: -50)
            self.rootNode.addChildNode(lineNode)
            
            // EXACTEMENT la même vitesse que les obstacles (60m en 2 secondes)
            let moveAction = SCNAction.moveBy(x: 0, y: 0, z: 60, duration: 2.0)
            let removeAction = SCNAction.removeFromParentNode()
            let sequence = SCNAction.sequence([moveAction, removeAction])
            
            lineNode.runAction(sequence)
        }
    }
    
    func prefillLineDashes() {
        let lineXPositions: [Float] = [-0.6, 0.0, 0.6]
        
        // On utilise "stride" pour générer des positions Z espacées de 6 mètres : -2, -8, -14... jusqu'à -50
        for startZ in stride(from: -2.0, through: -50.0, by: -6.0) {
            
            for x in lineXPositions {
                let lineGeo = SCNBox(width: 0.05, height: 0.01, length: 1.0, chamferRadius: 0)
                lineGeo.firstMaterial?.diffuse.contents = UIColor.white
                
                let lineNode = SCNNode(geometry: lineGeo)
                // On place la ligne à sa position de départ pré-calculée
                lineNode.position = SCNVector3(x: x, y: 0.01, z: Float(startZ))
                self.rootNode.addChildNode(lineNode)
                
                // On lui applique exactement la même animation de mouvement que les autres
                let moveAction = SCNAction.moveBy(x: 0, y: 0, z: 60, duration: 2.0)
                let removeAction = SCNAction.removeFromParentNode()
                let sequence = SCNAction.sequence([moveAction, removeAction])
                
                lineNode.runAction(sequence)
            }
        }
    }
    
    func spawnCloud() {
        // On crée une capsule blanche
        let cloudGeo = SCNCapsule(capRadius: 1.5, height: 6.0)
        cloudGeo.firstMaterial?.diffuse.contents = UIColor.white
        
        let cloudNode = SCNNode(geometry: cloudGeo)
        // On la tourne de 90 degrés (Pi / 2) pour la coucher à l'horizontale
        cloudNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 2)
        
        // On génère des positions aléatoires pour que le ciel soit naturel
        let randomX = Float.random(in: -20...20) // Très à gauche ou très à droite
        let randomY = Float.random(in: 10...20)  // Haut dans le ciel
        
        // On place le nuage très loin au fond (Z = -100)
        cloudNode.position = SCNVector3(x: randomX, y: randomY, z: -100)
        self.rootNode.addChildNode(cloudNode)
        
        // L'illusion de parallaxe : les nuages avancent beaucoup plus lentement que la route !
        // Ils parcourent 120 mètres en 15 secondes
        let moveAction = SCNAction.moveBy(x: 0, y: 0, z: 120, duration: 30.0)
        let removeAction = SCNAction.removeFromParentNode()
        let sequence = SCNAction.sequence([moveAction, removeAction])
        
        cloudNode.runAction(sequence)
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
    
    func startSpawningLines() {
        // 0.2 seconde crée un bon espace (vide) entre chaque trait blanc
        let wait = SCNAction.wait(duration: 0.2)
        let spawn = SCNAction.run { _ in
            self.spawnLineDashes()
        }
        let sequence = SCNAction.sequence([wait, spawn])
        
        // On nomme cette boucle "linesLoop"
        self.rootNode.runAction(SCNAction.repeatForever(sequence), forKey: "linesLoop")
    }
    
    
    // 2. Créer la fonction qui lance le chronomètre (à mettre avec tes autres fonctions)
    func startScoring() {
        // On attend 0.1 seconde
        let wait = SCNAction.wait(duration: 0.1)
        
        // On augmente le score et on prévient SwiftUI
        let increment = SCNAction.run { _ in
            self.score += 1
            // DispatchQueue assure que l'UI se met à jour sur le bon "fil" de traitement
            DispatchQueue.main.async {
                self.onScoreUpdate?(self.score)
            }
        }
        
        // On boucle à l'infini
        let sequence = SCNAction.sequence([wait, increment])
        self.rootNode.runAction(SCNAction.repeatForever(sequence), forKey: "scoringLoop")
    }
    
    
    func startSpawningClouds() {
        let wait = SCNAction.wait(duration: 3.0)
        let spawn = SCNAction.run { _ in
            self.spawnCloud()
        }
        let sequence = SCNAction.sequence([wait, spawn])
        
        // On nomme la boucle "cloudsLoop"
        self.rootNode.runAction(SCNAction.repeatForever(sequence), forKey: "cloudsLoop")
    }
    
    
    
}

extension GameScene: SCNPhysicsContactDelegate {
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        //print("💥 BOOM ! Collision détectée !")
        self.rootNode.removeAction(forKey: "spawningLoop")
        self.rootNode.removeAction(forKey: "scoringLoop")
        self.rootNode.removeAction(forKey: "linesLoop")
        self.rootNode.removeAction(forKey: "cloudsLoop")
        
        self.isPaused = true
        
        // On envoie le signal à SwiftUI sur le fil principal
        DispatchQueue.main.async {
            self.onGameOver?()
        }
    }
}
