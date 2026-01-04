//
//  StarView.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//

import SwiftUI

struct StarView: View {
    @ObservedObject var star: StarModel
    var onDragChanged: ((CGPoint) -> Void)?
    var onDragEnded: (() -> Void)?
    
    @State private var pulsePhase: CGFloat = 0
    @State private var dragLineVisible: Bool = false
    @State private var dragLinePoints: [CGPoint] = []
    
    var body: some View {
        if star.isVisible {
            ZStack {
                // Линия натягивания
                if star.isDragging && dragLineVisible && dragLinePoints.count >= 2 {
                    Path { path in
                        path.move(to: dragLinePoints[0])
                        path.addLine(to: dragLinePoints[1])
                    }
                    .stroke(LinearGradient(
                        colors: [star.color, star.color.opacity(0.3), star.color.opacity(0.1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ), style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .shadow(color: star.glowColor, radius: 5)
                }
                
                // Звезда
                ZStack {
                    Image(systemName: "star.fill")
                        .resizable()
                        .frame(width: star.size.width, height: star.size.height)
                        .foregroundColor(star.color)
                        .overlay(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    star.color,
                                    star.color.opacity(0.8),
                                    star.color.opacity(0.6)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .mask(Image(systemName: "star.fill").resizable())
                        )
                        .shadow(color: star.glowColor, radius: star.glowRadius)
                        .scaleEffect(star.scale * star.dragScale)
                        .rotationEffect(.degrees(star.rotation))
                        .opacity(star.opacity)
                    
                    // ОТОБРАЖЕНИЕ УРОВНЯ ДЛЯ ВСЕХ ЗВЕЗД
                    // Рассчитываем размер текста в зависимости от уровня и размера звезды
                    let fontSize: CGFloat = {
                        let baseSize = star.size.width * 0.5 // 20% от размера звезды
                        // Уменьшаем для больших чисел (чтобы влезло)
                        if star.level >= 100 { return baseSize * 0.3 }
                        if star.level >= 10 { return baseSize * 0.4 }
                        return baseSize * 0.5
                    }()
                    
                    Text("\(star.level)")
                        .font(.system(size: fontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 2)
                        .overlay(
                            Group {
                                if star.level == 5 {
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 3)
                                        .frame(width: star.size.width * 1.1, height: star.size.height * 1.1)
                                }
                            }
                        )
                        .offset(y: star.size.height * 0.02)
                }
                .overlay(
                    Group {
                        if star.isPulsing && !star.isDragging && !star.isInFlight {
                            Circle()
                                .stroke(star.glowColor, lineWidth: 2)
                                .frame(width: star.size.width * 1.5, height: star.size.height * 1.5)
                                .scaleEffect(1 + 0.2 * CGFloat(sin(Double(pulsePhase))))
                                .opacity(0.5 - 0.3 * CGFloat(sin(Double(pulsePhase))))
                        }
                    }
                )
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            if !star.isDragging {
                                star.startDrag(at: value.location)
                                dragLineVisible = true
                            }
                            star.updateDrag(to: value.location)
                            onDragChanged?(value.location)
                            
                            dragLinePoints = [
                                star.dragStartPosition,
                                value.location
                            ]
                        }
                        .onEnded { value in
                            star.endDrag()
                            onDragEnded?()
                            withAnimation(.easeOut(duration: 0.2)) {
                                dragLineVisible = false
                            }
                        }
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: star.dragScale)
            }
            .position(star.position)
            .onAppear {
                if star.isPulsing {
                    startPulseAnimation()
                }
            }
            .onChange(of: star.isPulsing) { _, isPulsing in
                if isPulsing {
                    startPulseAnimation()
                }
            }
        }
    }
    
    private func startPulseAnimation() {
        withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulsePhase = CGFloat.pi
        }
    }
}
