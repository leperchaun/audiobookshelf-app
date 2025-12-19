//
//  CarPlayImageLoader.swift
//  App
//
//  Created for CarPlay integration
//

import UIKit
import Foundation

class CarPlayImageLoader {

    private var imageCache = NSCache<NSURL, UIImage>()
    private var loadingTasks: [URL: URLSessionDataTask] = [:]
    private let queue = DispatchQueue(label: "com.audiobookshelf.carplay.imageloader")

    init() {
        imageCache.countLimit = 50
    }

    func loadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        // Check cache first
        if let cachedImage = imageCache.object(forKey: url as NSURL) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        // Check if already loading
        var isAlreadyLoading = false
        queue.sync {
            isAlreadyLoading = loadingTasks[url] != nil
        }
        if isAlreadyLoading {
            return
        }

        // Create request with auth header if needed
        var request = URLRequest(url: url)
        if let token = Store.serverConfig?.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Start download
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            self.queue.sync {
                self.loadingTasks.removeValue(forKey: url)
            }

            guard let data = data, let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // Resize image for CarPlay (max 90x90 for list items)
            let resizedImage = self.resizeImage(image, targetSize: CGSize(width: 90, height: 90))

            // Cache the image
            self.imageCache.setObject(resizedImage, forKey: url as NSURL)

            DispatchQueue.main.async {
                completion(resizedImage)
            }
        }

        queue.sync {
            loadingTasks[url] = task
        }

        task.resume()
    }

    func loadImage(from urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let urlString = urlString, let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }
        loadImage(from: url, completion: completion)
    }

    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height

        let ratio = min(widthRatio, heightRatio)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? image
    }

    func clearCache() {
        imageCache.removeAllObjects()
    }
}
