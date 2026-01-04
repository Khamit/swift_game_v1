//
//  MoneyStealAnimationView.swift
//  Nighty Tales
//
//  Created by Khamit on 28.12.2025.
//

// File: MoneyStealAnimationView.swift
import SwiftUI

struct MoneyStealAnimationView: View {
    let position: CGPoint
    let amount: Int
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    
    var body: some View {
        Text("-\(amount)$")
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.red)
            .shadow(color: .black, radius: 2)
            .position(
                x: position.x,
                y: position.y + offset
            )
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -50
                    opacity = 0
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    // Удаляем анимацию после завершения
                }
            }
    }
}
