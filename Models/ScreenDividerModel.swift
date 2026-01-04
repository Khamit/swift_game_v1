//
//  ScreenSplitModel.swift
//  Nighty Tales
//
//  Created by Khamit on 29.12.2025.
//

import SwiftUI
import Combine

final class ScreenDividerModel: ObservableObject {

    /// Доля экрана, занимаемая врагами (по умолчанию 50%)
    @Published private(set) var enemyRatio: CGFloat = 0.5

    var playerRatio: CGFloat {
        1.0 - enemyRatio
    }

    let minRatio: CGFloat = 0.0
    let maxRatio: CGFloat = 0.8

    /// Смещение баланса в сторону врагов
    func shiftTowardEnemy(by delta: CGFloat) {
        let newValue = enemyRatio + delta
        enemyRatio = min(max(newValue, minRatio), maxRatio)
    }

    /// Смещение баланса в сторону игрока
    func shiftTowardPlayer(by delta: CGFloat) {
        shiftTowardEnemy(by: -delta)
    }

    func reset() {
        enemyRatio = 0.5
    }
}
