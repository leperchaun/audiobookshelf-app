//
//  PlayerEvents.swift
//  App
//
//  Created by Rasmus Krämer on 14.04.22.
//

import Foundation

enum PlayerEvents: String {
    case update = "com.audiobookshelf.app.player.update"
    case closed = "com.audiobookshelf.app.player.closed"
    case sleepSet = "com.audiobookshelf.app.player.sleep.set"
    case sleepEnded = "com.audiobookshelf.app.player.sleep.ended"
    case failed = "com.audiobookshelf.app.player.failed"
    case localProgress = "com.audiobookshelf.app.player.localProgress"
    // CarPlay events
    case carPlayConnected = "com.audiobookshelf.app.carplay.connected"
    case carPlayDisconnected = "com.audiobookshelf.app.carplay.disconnected"
}
