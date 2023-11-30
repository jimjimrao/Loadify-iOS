//
//  ViewDetailsViewModel.swift
//  Loadify
//
//  Created by Vishweshwaran on 5/7/22.
//

import SwiftUI
import Combine
import LoggerKit
import Haptific

// Protocol combining loading, downloading, and error-handling capabilities
protocol Downloadable: Loadable, DownloadableError {
    var downloadStatus: DownloadStatus { get set }
    
    func downloadVideo(
        url: String,
        for platform: PlatformType,
        with quality: VideoQuality,
        isLastElement: Bool
    ) async
}

final class DownloaderViewModel: Downloadable {
    
    // Published properties for observing changes
    @Published var showLoader: Bool = false
    @Published var downloadError: Error? = nil
    @Published var errorMessage: String? = nil
    @Published var showSettingsAlert: Bool = false
    @Published var isDownloading: Bool = false
    @Published var downloadStatus: DownloadStatus = .none
    @Published var progress: Double = .zero
    
    // Services for handling photos and file operations
    private lazy var photoService: PhotosServiceProtocol = PhotosService()
    private lazy var fileService: FileServiceProtocol = FileService()
    
    // Object responsible for downloading
    private var downloader: Downloader?
    
    // Initializer for the ViewModel
    init() {
        Logger.initLifeCycle("DownloaderViewModel init", for: self)
        self.downloader = Downloader()
    }
    
    // Async function to download a video
    func downloadVideo(
        url: String,
        for platform: PlatformType,
        with quality: VideoQuality,
        isLastElement: Bool = true
    ) async {
        downloader?.delegate = self
        do {
            // Show loader while downloading
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showLoader = true
                
                withAnimation(.linear(duration: 0.5)) {
                    self.errorMessage = nil
                }
            }
            
            // Check for necessary permissions (in this case, Photos permission)
            try await photoService.checkForPhotosPermission()
            
            // Get temporary file path and download video
            try downloader?.download(url, for: platform, withQuality: quality)
        } catch PhotosError.permissionDenied {
            // Handle Photos permission denied error and update UI
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                withAnimation {
                    self.showSettingsAlert = true
                    self.showLoader = false
                    self.downloadStatus = .none
                }
                
                // Notify with haptics for a warning
                notifyWithHaptics(for: .warning)
            }
        } catch {
            // Handle other errors and update UI
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                withAnimation {
                    self.downloadError = error
                    self.showLoader = false
                }
                self.downloadStatus = .failed
                
                // Notify with haptics for an error
                notifyWithHaptics(for: .error)
            }
        }
    }
    
    // Private function to save media to Photos album if compatible
    private func saveMediaToPhotosAlbumIfCompatiable(
        at filePath: String,
        downloadType: Downloader.DownloadType
    ) throws {
        switch downloadType {
        case .video:
            // Save video to Photos album if compatible
            if !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath) {
                throw DownloadError.notCompatible
            }
            UISaveVideoAtPathToSavedPhotosAlbum(filePath, nil, nil, nil)
        case .photo:
            // Save photo to Photos album if compatible
            guard let image = UIImage(contentsOfFile: filePath) else {
                throw DownloadError.notCompatible
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    deinit {
        downloader?.invalidateTasks()
        Logger.deinitLifeCycle("DownloaderViewModel deinit", for: self)
    }
}

extension DownloaderViewModel: DownloaderDelegate {
    
    func downloader(didUpdateProgress progress: CGFloat) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            
            if self.showLoader {
                self.showLoader = false
                self.isDownloading = true
            }

            self.progress = progress
        }
    }
    
    func downloader(didCompleteDownloadWithURL url: URL, forType: Downloader.DownloadType) {
        do {
            let filePath = fileService.getTemporaryFilePath()
            try fileService.moveFile(from: url, to: filePath)
            
            // Save media to Photos album if compatible
            try saveMediaToPhotosAlbumIfCompatiable(at: filePath.path, downloadType: forType)
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isDownloading = false
                self.downloadStatus = .downloaded
            }
            
            notifyWithHaptics(for: .success)
        } catch {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.showLoader = false
                self.downloadStatus = .failed
            }
        }
    }
    
    func downloader(didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showLoader = false
            self.downloadStatus = .failed
            self.errorMessage = errorMessage
            self.errorMessage = "Failed to Download"
        }
        
        notifyWithHaptics(for: .error)
    }
    
    func downloader(didFailWithErrorMessage errorMessage: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showLoader = false
            self.downloadStatus = .failed
            self.errorMessage = errorMessage
        }
        
        notifyWithHaptics(for: .error)
    }
}
