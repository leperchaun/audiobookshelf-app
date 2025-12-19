//
//  CarPlayNowPlayingManager.swift
//  App
//
//  Created for CarPlay integration
//

import CarPlay
import MediaPlayer
import Foundation

class CarPlayNowPlayingManager {

    init() {
        setupNowPlayingTemplate()
    }

    private func setupNowPlayingTemplate() {
        let nowPlayingTemplate = CPNowPlayingTemplate.shared

        // Configure playback buttons
        nowPlayingTemplate.isUpNextButtonEnabled = false
        nowPlayingTemplate.isAlbumArtistButtonEnabled = false

        // Add custom skip buttons based on device settings
        updateNowPlayingButtons()
    }

    func updateNowPlayingButtons() {
        let nowPlayingTemplate = CPNowPlayingTemplate.shared
        let deviceSettings = Database.shared.getDeviceSettings()

        var buttons: [CPNowPlayingButton] = []

        // Skip backward button
        let skipBackwardImage = UIImage(systemName: "gobackward.\(deviceSettings.jumpBackwardsTime)") ?? UIImage(systemName: "gobackward")!
        let skipBackwardButton = CPNowPlayingImageButton(image: skipBackwardImage) { _ in
            PlayerHandler.seekBackward(amount: Double(deviceSettings.jumpBackwardsTime))
        }
        buttons.append(skipBackwardButton)

        // Skip forward button
        let skipForwardImage = UIImage(systemName: "goforward.\(deviceSettings.jumpForwardTime)") ?? UIImage(systemName: "goforward")!
        let skipForwardButton = CPNowPlayingImageButton(image: skipForwardImage) { _ in
            PlayerHandler.seekForward(amount: Double(deviceSettings.jumpForwardTime))
        }
        buttons.append(skipForwardButton)

        nowPlayingTemplate.updateNowPlayingButtons(buttons)
    }

    func updateNowPlaying() {
        // The existing NowPlayingInfo class already updates MPNowPlayingInfoCenter
        // CarPlay automatically uses this data through the system's now playing info
        // This method is available for any CarPlay-specific updates if needed

        // Update buttons in case settings changed
        updateNowPlayingButtons()
    }

    func clearNowPlaying() {
        // Clear is handled by NowPlayingInfo.reset()
        // CarPlay automatically reflects this through MPNowPlayingInfoCenter
    }
}
