//
//  ApiService+Extension.swift
//  Loadify
//
//  Created by Vishweshwaran on 08/06/22.
//

import Foundation
import UIKit

extension ApiService {
    
    /// A generic function helps to decode data from the server
    ///
    /// For instance, if you want to decode your data to your custom struct, class or enum use `decode` method.
    ///  ````
    ///  struct UserInfo: Codeable {
    ///    var id: Int
    ///    var name: String
    ///  }
    ///  ````
    ///  Now to convert data to JSON use `decode` method as show below
    ///  ````
    ///  let decodedData = decode(data, to: UserInfo.self)
    ///  ````
    func decode<T: Codable>(_ data: Data, to type: T.Type) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ServerError.decodeFailed
        }
    }
    
    func checkIsValidUrl(_ url: String) throws {
        if url.checkIsEmpty() {
            throw DetailsError.emptyUrl
        }
    }
    
    /// This function is used to create URLRequest instance
    func createUrlRequest(for url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        return urlRequest
    }
    
    // TODO: - Needed to handle this function effectively
    /// This function handles server side errors
    func checkForServerErrors(for urlResponse: URLResponse, with data: Data) async throws {
        if let response = urlResponse as? HTTPURLResponse {
            switch response.statusCode {
            case 200...299:
                break
            case 400...499:
                let decodedErrorData = try decode(data, to: ErrorModel.self)
                if decodedErrorData.message == ServerError.notValidDomain.localizedDescription {
                    throw DetailsError.notVaildYouTubeUrl
                } else if decodedErrorData.message == ServerError.requestedQualityUnavailable.localizedDescription {
                    throw DownloadError.qualityNotAvailable
                } else if decodedErrorData.message == ServerError.durationTooHigh.localizedDescription {
                    throw DownloadError.durationTooHigh
                } else {
                    throw URLError(.badURL)
                }
            case 500...599:
                throw ServerError.internalServerError
            default:
                throw URLError(.badServerResponse)
            }
        }
    }
    
    func getUrl(from urlString: String) throws ->  URL {
        guard let url = URL(string: urlString) else { throw DetailsError.invaildApiUrl }
        return url
    }
    
    func checkVideoIsCompatible(at filePath: String) throws {
        if !UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(filePath) {
            throw DownloadError.notCompatible
        }
    }
}
