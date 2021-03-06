/**
 * Copyright (c) 2016 Ivan Magda
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import UIKit.UIImage

// MARK: Types

enum Period: String {
    case Day = "day"
    case Week = "week"
}

// MARK: - Typealiases

typealias FlickrFailureCompletionHandler = (error: NSError) -> Void
typealias FlickrTagsSuccessCompletionHandler = (tags: [FlickrTag]) -> Void
typealias FlickrPhotosSearchSuccessCompletionHandler = (album: FlickrAlbum) -> Void
typealias FlickrNumberSuccessCompletionHandler = (number: Int) -> Void
typealias FlickrPhotoSuccessCompletionHandler = (photo: FlickrPhoto) -> Void
typealias FlickrPhotosSuccessCompletionHandler = (photos: [FlickrPhoto]) -> Void
typealias FlickrPersonInfoSuccessCompletionHandler = (person: FlickrPersonInfo) -> Void

// MARK: - FlickrApiClient (Calling Api Endpoints)

extension FlickrApiClient {
    
    // MARK: - Tags -
    // MARK: Public
    
    func tagsHotListForPeriod(period: Period, numberOfTags count: Int = 20, successBlock success: FlickrTagsSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        var param = getBaseMethodParameters(Constants.FlickrParameterValues.TagsHotList)
        param[Constants.FlickrParameterKeys.Period] = period.rawValue
        param[Constants.FlickrParameterKeys.Count] = count
        
        let keys = [Constants.FlickrResponseKeys.HotTags, Constants.FlickrResponseKeys.Tag]
        let request = NSURLRequest(URL: urlFromParameters(param))
        fetchCollectionForRequest(request, rootKeys: keys, success: success, fail: fail)
    }
    
    func relatedTagsForTag(tag: String, successBlock success: FlickrTagsSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        var param = getBaseMethodParameters(Constants.FlickrParameterValues.TagsGetRelated)
        param[Constants.FlickrParameterKeys.Tag] = tag
        
        let keys = [Constants.FlickrResponseKeys.Tags, Constants.FlickrResponseKeys.Tag]
        let request = NSURLRequest(URL: urlFromParameters(param))
        fetchCollectionForRequest(request, rootKeys: keys, success: success, fail: fail)
    }
    
    // MARK: - Photos -
    // MARK: Public
    
    func searchPhotosWithTags(tags: [String], successBlock success: FlickrPhotosSearchSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        searchPhotosWithParameters(parametersForPhotosSearchWithTags(tags), successBlock: success, failBlock: fail)
    }
    
    func randomImageFromTags(tags: [String], successBlock success: ImageDownloadingCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        randomPhotoForPhotosSearchWithParameters(parametersForPhotosSearchWithTags(tags), successBlock: { [unowned self] photo in
            guard let url = NSURL(string: photo.urlSmall) else {
                fail(error: Constants.Error.DefaultError)
                return
            }
            self.downloadImageWithURL(url, successBlock: success, failBlock: fail)
            }, failBlock: fail)
    }
    
    func randomPhotoForPhotosSearchWithParameters(parameters: MethodParameters, successBlock success: FlickrPhotoSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        countPagesForPhotoSearchWithParameters(parameters, successBlock: { pages in
            let pageLimit = min(pages, 20)
            let randomPage = RandomNumberUtils.numberFromZeroTo(pageLimit) + 1
            
            var parameters = parameters
            parameters[Constants.FlickrParameterKeys.Page] = randomPage
            self.searchPhotosWithParameters(parameters, successBlock: { album in
                guard album.photos.count > 0 else {
                    fail(error: Constants.Error.EmptyResponseError)
                    return
                }
                
                let randomIndex = RandomNumberUtils.numberFromZeroTo(album.photos.count)
                success(photo: album.photos[randomIndex])
                }, failBlock: fail)
            }, failBlock: fail)
    }
    
    // MARK: Private
    
    private func searchPhotosWithParameters(param: MethodParameters, successBlock success: FlickrPhotosSearchSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        let request = NSURLRequest(URL: urlFromParameters(param))
        fetchResourceForRequest(request, success: success, fail: fail)
    }
    
    /// Returns number of pages for a photos search.
    private func countPagesForPhotoSearchWithParameters(param: MethodParameters, successBlock success: FlickrNumberSuccessCompletionHandler, failBlock fail: FlickrFailureCompletionHandler) {
        let request = NSURLRequest(URL: urlFromParameters(param))
        fetchJsonForRequest(request) { result in
            func sendError(error: String) {
                self.debugLog("Error: \(error)")
                let error = NSError(
                    domain: Constants.Error.NumberOfPagesForPhotoSearchErrorDomain,
                    code: Constants.Error.NumberOfPagesForPhotoSearchErrorCode,
                    userInfo: [NSLocalizedDescriptionKey : error])
                fail(error: error)
            }
            
            switch result {
            case .Error(let error):
                sendError(error.localizedDescription)
            case .Json(let json):
                guard let photosDictionary = json[Constants.FlickrResponseKeys.Photos] as? JSONDictionary,
                    let numberOfPages = photosDictionary[Constants.FlickrResponseKeys.Pages] as? Int else {
                        sendError("Could't parse recieved JSON object")
                        return
                }
                success(number: numberOfPages)
            default:
                sendError(result.defaultErrorMessage()!)
            }
        }
    }
    
    // MARK: - User -
    
    func getPersonInfoWithNSID(userID: String, success: FlickrPersonInfoSuccessCompletionHandler, failure: FlickrFailureCompletionHandler) {
        var parameters = getBaseMethodParameters(Constants.FlickrParameterValues.PeopleGetInfo)
        parameters[Constants.FlickrParameterKeys.UserID] = userID
        
        let request = NSURLRequest(URL: urlFromParameters(parameters))
        fetchResourceForRequest(request, success: success, fail: failure)
    }
    
    func getProfilePictureFromUserInfo(info: FlickrPersonInfo, success: ImageDownloadingCompletionHandler, failure: FlickrFailureCompletionHandler) {
        let URL = NSURL(string: "https://farm\(info.iconFarm).staticflickr.com/\(info.iconServer)/buddyicons/\(info.nsid)_l.jpg")!
        downloadImageWithURL(URL, successBlock: success, failBlock: failure)
    }
    
    func getProfilePictureWithNSID(nsid: String, success: ImageDownloadingCompletionHandler, failure: FlickrFailureCompletionHandler) {
        getPersonInfoWithNSID(nsid,
                    success: { self.getProfilePictureFromUserInfo($0, success: success, failure: failure) },
                    failure: failure)
    }
    
    // MARK: - Authenticated Requests -
    
    func testLogin(completionHandler: (success: Bool, error: NSError?) -> Void) {
        func sendError(error: String) {
            self.debugLog("Error: \(error)")
            let error = NSError(
                domain: Constants.Error.ErrorDomain,
                code: Constants.Error.DefaultErrorCode,
                userInfo: [NSLocalizedDescriptionKey : error])
            completionHandler(success: false, error: error)
        }
        
        let params = [
            Constants.FlickrParameterKeys.Method: Constants.FlickrParameterValues.TestLogin,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat
        ]
        
        guard let URL = FlickrApiClient.getTempOAuth().buildSHAEncryptedURLForHTTPMethod(.GET, baseURL: baseURL, requestParameters: params) else {
            sendError("Could not build HMAC-SHA1 encrypted URL. Try to login in your Flickr account.")
            return
        }
        
        fetchJsonForRequest(NSURLRequest(URL: URL)) { result in
            switch result {
            case .Error(let error):
                sendError(error.localizedDescription)
            case .Json(let json):
                guard self.checkFlickrResponse(json) == true else {
                    sendError("Flickr API return an error.")
                    return
                }
                print("TEST_LOGIN_SUCCESS: \(json)")
                completionHandler(success: true, error: nil)
            default:
                sendError(result.defaultErrorMessage()!)
            }
        }
    }
    
    func getUserPhotos(user: FlickrUser, success: FlickrPhotosSuccessCompletionHandler, failure: FlickrFailureCompletionHandler) {
        var parameters = Parameters()
        getBaseParametersForPhotosSearch().forEach { parameters[$0] = "\($1)" }
        parameters[Constants.FlickrParameterKeys.PerPage] = "\(Constants.FlickrParameterValues.PerPageMax)"
        parameters[Constants.FlickrResponseKeys.UserID] = user.userID
        
        guard let URL = FlickrApiClient.getTempOAuth().buildSHAEncryptedURLForHTTPMethod(.GET, baseURL: baseURL, requestParameters: parameters) else {
            return
        }
        
        let request = NSURLRequest(URL: URL)
        fetchCollectionForRequest(request, rootKeys: ["photos", "photo"], success: success, fail: failure)
    }
    
    // MARK: Private
    
    private class func getTempOAuth() -> FlickrOAuth {
        return FlickrOAuth(consumerKey: FlickrApplicationKey, consumerSecret: FlickrApplicationSecret, callbackURL: "")
    }
    
    // MARK: - Private Helpers -
    
    func getBaseMethodParameters(method: String? = nil) -> MethodParameters {
        var parameters = [
            Constants.FlickrParameterKeys.APIKey: Constants.FlickrParameterValues.APIKey,
            Constants.FlickrParameterKeys.Format: Constants.FlickrParameterValues.ResponseFormat,
            Constants.FlickrParameterKeys.NoJSONCallback: Constants.FlickrParameterValues.DisableJSONCallback
        ]
        if let method = method { parameters[Constants.FlickrParameterKeys.Method] = method }
        return parameters
    }
    
    private func getBaseParametersForPhotosSearch() -> MethodParameters {
        var methodParameters = getBaseMethodParameters(Constants.FlickrParameterValues.SearchMethod)
        methodParameters[Constants.FlickrParameterKeys.Extras] = "\(Constants.FlickrParameterValues.ThumbnailURL),\(Constants.FlickrParameterValues.SmallURL),\(Constants.FlickrParameterValues.MediumURL)"
        methodParameters[Constants.FlickrParameterKeys.ContentType] = Constants.FlickrParameterValues.ContentType.Photos.rawValue
        methodParameters[Constants.FlickrParameterKeys.SafeSearch] = Constants.FlickrParameterValues.UseSafeSearch
        methodParameters[Constants.FlickrParameterKeys.Page] = 1
        methodParameters[Constants.FlickrParameterKeys.PerPage] = Constants.FlickrParameterValues.PerPageDefault
        return methodParameters
    }
    
    private func parametersForPhotosSearchWithTags(tags: [String]) -> MethodParameters {
        var methodParameters = getBaseParametersForPhotosSearch()
        methodParameters[Constants.FlickrParameterKeys.Tags] = tags.joinWithSeparator(",")
        return methodParameters
    }
    
    private func checkFlickrResponse(json: JSONDictionary) -> Bool {
        guard let flickrStatus = json[Constants.FlickrResponseKeys.Status] as? String where flickrStatus == Constants.FlickrResponseValues.OKStatus else {
            return false
        }
        return true
    }
    
}
