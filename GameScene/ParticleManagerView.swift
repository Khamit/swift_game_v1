//
//  ParticleManagerView.swift
//  Nighty Tales
//
//  Created by Khamit on 30.12.2025.
//
/*
// ParticleManagerView.swift
import SwiftUI

struct ParticleManagerView: View {
    @ObservedObject var particleSystem: ParticleSystem
    @State private var lastUpdate = Date()
    
    var body: some View {
        ZStack {
            ForEach(particleSystem.particles) { particle in
                ParticleView(particle: particle)
            }
        }
        .onAppear {
            lastUpdate = Date()
        }
        .onReceive(Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()) { _ in
            let now = Date()
            let deltaTime = now.timeIntervalSince(lastUpdate)
            lastUpdate = now
            
            particleSystem.update(deltaTime: deltaTime)
        }
    }
}
*/
