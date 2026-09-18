import SwiftUI

struct SettingsView: View {
    @Binding var appState: AppState
    
    // --- SAUVEGARDE AUTOMATIQUE DES PRÉFÉRENCES ---
    @AppStorage("isMusicEnabled") private var isMusicEnabled = true
    @AppStorage("isHapticsEnabled") private var isHapticsEnabled = true
    @AppStorage("speedUnit") private var speedUnit = "km/h"
    @AppStorage("weatherSetting") private var weatherSetting = "Sun"
    @AppStorage("trafficMode") private var trafficMode = "One Way"
    @AppStorage("gameMode") private var gameMode = "Casual"
    
    // --- LES CHOIX POUR LES MENUS ---
    let weathers = ["Sun", "Sunset", "Night", "Rain", "Fog", "Snow", "Random"]
    let trafficModes = ["One Way", "Oncoming", "Two-Way"] // Sens unique, inverse, les deux
    let gameModes = ["Casual", "Bomb", "Time Trial"]
    
    var body: some View {
        ZStack {
            Color(UIColor.darkGray).ignoresSafeArea()
            
            VStack(spacing: 25) {
                
                // --- 1. EN-TÊTE ---
                HStack {
                    Button(action: { appState = .menu }) {
                        Image(systemName: "chevron.left")
                            .font(.title2).bold()
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("SETTINGS").font(.system(size: 30, weight: .heavy, design: .rounded)).foregroundColor(.white)
                    Spacer()
                    Spacer().frame(width: 50) // Équilibre visuel pour centrer le texte
                }
                .padding()
                
                // --- 2. BOUTONS MUSIC & VIBRATION ---
                HStack(spacing: 50) {
                    Button(action: { isMusicEnabled.toggle() }) {
                        VStack {
                            Image(systemName: isMusicEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isMusicEnabled ? .green : .red)
                            Text("Music")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                    }
                    
                    Button(action: { isHapticsEnabled.toggle() }) {
                        VStack {
                            Image(systemName: isHapticsEnabled ? "iphone.radiowaves.left.and.right" : "iphone.slash")
                                .font(.system(size: 40))
                                .foregroundColor(isHapticsEnabled ? .green : .red)
                            Text("Haptics")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top, 5)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                // --- 3. LES RÉGLAGES DU JEU ---
                VStack(spacing: 25) {
                    
                    // Compteur de vitesse
                    HStack {
                        Text("Speed Unit").font(.title3).bold().foregroundColor(.white)
                        Spacer()
                        Picker("Speed Unit", selection: $speedUnit) {
                            Text("km/h").tag("km/h")
                            Text("mph").tag("mph")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 140)
                    }
                    
                    // Météo
                    HStack {
                        Text("Weather").font(.title3).bold().foregroundColor(.white)
                        Spacer()
                        Picker("Weather", selection: $weatherSetting) {
                            ForEach(weathers, id: \.self) { Text($0) }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.yellow)
                    }
                    
                    // Trafic
                    HStack {
                        Text("Traffic").font(.title3).bold().foregroundColor(.white)
                        Spacer()
                        Picker("Traffic", selection: $trafficMode) {
                            ForEach(trafficModes, id: \.self) { Text($0) }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.yellow)
                    }
                    
                    // Mode de jeu
                    HStack {
                        Text("Game Mode").font(.title3).bold().foregroundColor(.white)
                        Spacer()
                        Picker("Game Mode", selection: $gameMode) {
                            ForEach(gameModes, id: \.self) { Text($0) }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.yellow)
                    }
                }
                .padding(25)
                .background(Color.black.opacity(0.4))
                .cornerRadius(20)
                .padding(.horizontal, 25)
                
                Spacer()
                
                // --- 4. SIGNATURE ---
                VStack(spacing: 5) {
                    Text("Shift v1.0.0")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.gray)
                    Text("Made by Arthvrr")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .padding(.bottom, 30)
            }
        }
        // Petit hack SwiftUI pour que le "SegmentedPicker" soit joli en mode sombre
        .onAppear {
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.systemBlue
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white], for: .normal)
        }
    }
}
