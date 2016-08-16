//
//  BingSearch.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/15/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation

typealias SearchCallback = (searchResults: [ResultModel], searchCount: Int64?, errorDescription: String?) -> ()

class BingSearch: NSObject
{
    private let searchCallback: SearchCallback
    private var currentSessionTask: NSURLSessionTask?
    private var lastRequestTimeStamp: NSTimeInterval?
    
    init(searchCallback schClbk: SearchCallback)
    {
        searchCallback = schClbk
        super.init()
    }
    
    func search(phrase: String, searchImages: Bool, firstItemNumber: Int64)
    {
        if currentSessionTask != nil
        {
            currentSessionTask?.cancel()
            currentSessionTask = nil
        }
        
        guard let request = searchRequest(phrase, searchImages: searchImages, firstItemNumber: firstItemNumber) else {return}
        let requestTimeStamp = NSDate.timeIntervalSinceReferenceDate()
        lastRequestTimeStamp = requestTimeStamp
        currentSessionTask = NSURLSession.sharedSession().dataTaskWithRequest(request) {[weak self](data, response, error) in
            
            guard let strongSelf = self else {return}
            guard error == nil else
            {
                print("Network error. Status code \(error!.code)")
                if error!.code != NSURLErrorCancelled
                {
                    strongSelf.searchCallback(searchResults: [], searchCount: nil, errorDescription: "Network failure. Please retry.")
                }
                return
            }
            
            guard let data = data else
            {
                print("Error. Server returned no data.")
                strongSelf.searchCallback(searchResults: [], searchCount: nil, errorDescription: "Server returned no data. Please retry or try another search key.")
                return
            }
            
            guard strongSelf.isRequestStilValid(requestTimeStamp) else {return}
            
            var foundItems: [ResultModel]
            var searchCount: Int64?
            if searchImages
            {
                foundItems = strongSelf.parseImageSearchData(data)
            }
            else
            {
                foundItems = strongSelf.parseStringSearchData(data)
                searchCount = strongSelf.parseStringSearchItemsCount(data)
            }
            
            guard strongSelf.isRequestStilValid(requestTimeStamp) else {return}
            strongSelf.searchCallback(searchResults: foundItems, searchCount: searchCount, errorDescription: nil)
        }
        
        currentSessionTask?.resume()
    }
    
    func isRequestStilValid(requestTimeStamp: NSTimeInterval) -> Bool
    {
        guard let agentRequest = lastRequestTimeStamp else {return false}
        return abs(agentRequest - requestTimeStamp) < DBL_EPSILON
    }
    
    func searchRequest(searchPhrase: String, searchImages: Bool, firstItemNumber: Int64) -> NSURLRequest?
    {
        guard let escapedSearchString = searchPhrase.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet()) else {return nil}
        
        var requestString: String!
        if searchImages
        {
            requestString = "https://www.bing.com/images/search?q=" + escapedSearchString + "&first=" + String(firstItemNumber)
        }
        else
        {
            requestString = "https://www.bing.com/search?q=" + escapedSearchString + "&first=" + String(firstItemNumber)
        }
        guard let url = NSURL(string: requestString) else {return nil}
        return NSURLRequest(URL: url)
    }
    
    func parseStringSearchData(data: NSData) -> [ResultModel]
    {
        let doc = TFHpple(HTMLData: data)
        var foundItems = doc.searchWithXPathQuery("//li[@class='b_algo']/h2/a") as? [TFHppleElement]
        if let additioanlItems = doc.searchWithXPathQuery("//li[@class='b_algo']/div[@class='b_title']/h2/a") as? [TFHppleElement]
        {
            foundItems? += additioanlItems
        }
        
        guard let items = foundItems where items.count > 0 else {return []}
        
        var parsedResults = [ResultModel]()
        for htmlItem in items
        {
            if let model = parseHTMLStringSearchItem(htmlItem)
            {
                parsedResults.append(model)
            }
        }
        return parsedResults
    }
    
    func parseHTMLStringSearchItem(htmlItem: TFHppleElement) -> ResultModel?
    {
        guard let urlString = htmlItem["href"] as? String else {return nil}
        let resultStruct = ResultStruct(title: htmlItem.content, url: NSURL(string: urlString), imageURL: nil)
        return ResultModel(resultStruct: resultStruct, isImageResult: false)
    }
    
    func parseImageSearchData(data: NSData) -> [ResultModel]
    {
        let doc = TFHpple(HTMLData: data)
        let foundItems = doc.searchWithXPathQuery("//div[@class='item']") as? [TFHppleElement]
        
        guard let items = foundItems where items.count > 0 else {return []}
        
        var parsedResults = [ResultModel]()
        for htmlItem in items
        {
            if let model = parseHTMLImageSearchItem(htmlItem)
            {
                parsedResults.append(model)
            }
        }
        return parsedResults
    }
    
    func parseHTMLImageSearchItem(htmlItem: TFHppleElement) -> ResultModel?
    {
        let foundThumbs = htmlItem.searchWithXPathQuery("//div[@class='cico']/img")
        guard let thumb = foundThumbs.first as? TFHppleElement, thumbURLString = thumb["src"] as? String else {return nil}
        
        let foundInfoItems = htmlItem.searchWithXPathQuery("//div[@class='des']")
        guard let infoItem = foundInfoItems.first as? TFHppleElement, title = infoItem.content else {return nil}
        
        let foundLinks = htmlItem.searchWithXPathQuery("//a[@class='tit']")
        guard let linkItem = foundLinks.first as? TFHppleElement, linkString = linkItem["href"] as? String else {return nil}
        
        let resultStruct = ResultStruct(title: title, url: NSURL(string: linkString), imageURL: NSURL(string: thumbURLString))
        return ResultModel(resultStruct: resultStruct, isImageResult: true)
    }
    
    func parseStringSearchItemsCount(data: NSData) -> Int64?
    {
        let doc = TFHpple(HTMLData: data)
        let foundResultsCount = doc.searchWithXPathQuery("//span[@class='sb_count']")
        guard let resultsCountItem = foundResultsCount.first as? TFHppleElement else {return nil}
        let resultsCountString = resultsCountItem.content
        let components = resultsCountString.componentsSeparatedByString(" ")
        var count: Int64?
        for var component in components
        {
            component = component.stringByReplacingOccurrencesOfString(",", withString: "")
            component = component.stringByReplacingOccurrencesOfString(".", withString: "")
            if let resultsNumber = Int64(component)
            {
                count = resultsNumber
                break
            }
        }
        return count
    }
}


