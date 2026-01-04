//
//  FPSCounter.swift
//  Nighty Tales
//
//  Created by Khamit on 19.12.2025.
//

import SwiftUI
import Combine

final class FPSCounter: ObservableObject {
    @Published private(set) var fps: Int = 0

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0

    func start() {
        stop()

        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        frameCount = 0
    }

    @objc private func tick(link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let delta = link.timestamp - lastTimestamp

        if delta >= 1 {
            fps = Int(Double(frameCount) / delta)
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
}

struct FPSView: View {
    @ObservedObject var counter: FPSCounter

    var body: some View {
        Text("FPS \(counter.fps)")
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(counter.fps >= 55 ? .green : .red)
            .padding(6)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding([.top, .leading], 10)
    }
}
