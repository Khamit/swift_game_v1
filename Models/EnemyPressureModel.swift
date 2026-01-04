//
//  EnemyPressureModel.swift
//  Nighty Tales
//
//  Created by Khamit on 29.12.2025.
//
import SwiftUI
import Combine

final class EnemyPressureModel: ObservableObject {

    @ObservedObject var screenSplit: ScreenDividerModel

    private var timer: Timer?

    init(screenSplit: ScreenDividerModel) {
        self.screenSplit = screenSplit
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.screenSplit.shiftTowardEnemy(by: 0.05)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
