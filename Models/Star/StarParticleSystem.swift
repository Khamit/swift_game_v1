//
//  StarParticleSystem.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//
//

import SwiftUI
import Combine

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var color: Color
    var size: CGFloat
    var life: CGFloat // от 0 до 1
    var rotation: Double
    var scale: CGFloat
}

class ParticleSystem: ObservableObject {
    @Published var particles: [Particle] = []
    @Published var isActive = false
    
    func emit(at position: CGPoint, count: Int = 25, color: Color = .yellow) {
        particles.removeAll()
        
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(.pi * 2))
            let speed = CGFloat.random(in: 100...300)
            let velocity = CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed
            )
            
            particles.append(Particle(
                position: position,
                velocity: velocity,
                color: [
                    color,
                    color.opacity(0.8),
                    .orange,
                    .white
                ].randomElement()!,
                size: CGFloat.random(in: 8...20),
                life: 1.0,
                rotation: Double.random(in: 0...360),
                scale: CGFloat.random(in: 0.5...1.5)
            ))
        }
        
        isActive = true
    }
    
    func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        
        for i in particles.indices {
            // Обновляем позицию
            particles[i].position.x += particles[i].velocity.x * CGFloat(deltaTime)
            particles[i].position.y += particles[i].velocity.y * CGFloat(deltaTime)
            
            // Уменьшаем жизнь
            particles[i].life -= CGFloat(deltaTime) * 2
            
            // Уменьшаем размер
            particles[i].size *= 0.98
            
            // Вращаем
            particles[i].rotation += 100 * deltaTime
        }
        
        // Удаляем мертвые частицы
        particles.removeAll { $0.life <= 0 }
        
        // Если частиц не осталось, деактивируем систему
        if particles.isEmpty {
            isActive = false
        }
    }
}

struct ParticleView: View {
    let particle: Particle
    
    var body: some View {
        Image(systemName: "sparkle")
            .resizable()
            .frame(width: particle.size, height: particle.size)
            .foregroundColor(particle.color)
            .rotationEffect(.degrees(particle.rotation))
            .scaleEffect(particle.scale)
            .opacity(particle.life)
            .position(particle.position)
            .blur(radius: particle.life < 0.3 ? 2 : 0)
    }
}

struct StarParticleExplosionView: View {
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
