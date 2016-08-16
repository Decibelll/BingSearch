//
//  BingParser.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/13/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation

protocol ParserDelegate: class
{
    func parserDidParsedResults(searchResults: [ResultModel])
    func parseErrorOccured(error: NSError)
}

class StringSearchParser: NSObject, NSXMLParserDelegate
{
    var resultsNumber: Int64 = 0
    weak var delegate: ParserDelegate?
    
    private var parser: NSXMLParser!
    private var currentResult: ResultStruct?
    private var currentResultContentString: String?
    private var resultsCountString: String?
    private var parsedItems = [ResultModel]()
    private var currentXMLClassElement: String?
    private var currentXMLClass: String?
    private var cancelled = false
    private var recognizedClasses: Set<String>
    
    private let kStringSearchResultClassID = "b_algo"
    private let kStringSearchResultsCountClassID = "sb_count"
    private let kStringSearchContentStringElement = "h2"
    
    init?(searchPhrase: String, parserDelegate: ParserDelegate, startItem: Int = 0)
    {
        recognizedClasses = [kStringSearchResultClassID, kStringSearchResultsCountClassID]
        delegate = parserDelegate
        let trimmedSearchPhrase = searchPhrase.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        guard trimmedSearchPhrase.characters.count > 0 else {return nil}
        
//        let requestString = ("https://www.bing.com/search?q=" + trimmedSearchPhrase + "&first=" + String(startItem)).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        let requestString = "https://www.bing.com/search?q=car".stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
        guard let escapedRequestString = requestString else {return nil}
        
        let url = NSURL(string: escapedRequestString)
        guard let requestURL = url else {return nil}
        
        guard let localParser = NSXMLParser(contentsOfURL: requestURL) else {return nil}
        parser = localParser
        super.init()
        parser.delegate = self
    }
    
    func cancel()
    {
        cancelled = true
        parser.abortParsing()
    }
    
    func search()
    {
        parser.parse()
    }
    
    // MARK: NSXMLParserDelegate
    func parser(parser: NSXMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String])
    {
        print("Parser started element \(elementName), \(attributeDict)")
        if let classID = attributeDict["class"] where recognizedClasses.contains(classID)
        {
            currentXMLClassElement = elementName
            currentXMLClass = classID
        }
        
        // Parsing is based on handling of classes
        guard let classID = currentXMLClass else {return}
        
        switch classID
        {
        case kStringSearchResultClassID:
            if let _ = currentResult
            {
                if elementName == kStringSearchContentStringElement
                {
                    currentResultContentString = ""
                    return
                }
                
                // We only grab url string when parsing kStringSearchContentStringElement element (here currentResultContentString should be not nil)
                if let _ = currentResultContentString, urlString = attributeDict["href"]
                {
                    if let url = NSURL(string: urlString)
                    {
                        currentResult!.url = url
                    }
                }
            }
            else
            {
                currentResult = ResultStruct()
            }
            
        case kStringSearchResultsCountClassID:
            break
            
        default:
            break
        }
    }
    
    func parser(parser: NSXMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?)
    {
        // Parsing is based on handling of classes
        guard let classID = currentXMLClass else {return}
        
        switch classID
        {
        case kStringSearchResultClassID:
            guard let _ = currentResult else {return}
            
            if elementName == kStringSearchContentStringElement
            {
                currentResult!.title = currentResultContentString
                currentResultContentString = nil
                return
            }
            
            guard elementName == currentXMLClassElement else {return}
            if let result = ResultModel(resultStruct: currentResult!, isImageResult: false)
            {
                parsedItems.append(result)
            }
            currentResult = nil
            
        case kStringSearchResultsCountClassID:
            break
            
        default:
            break
        }
        
        if elementName == currentXMLClassElement
        {
            currentXMLClassElement = nil
            currentXMLClass = nil
        }
    }
    
    func parserDidEndDocument(parser: NSXMLParser)
    {
        if !cancelled
        {
            delegate?.parserDidParsedResults(parsedItems)
        }
    }
    
    func parser(parser: NSXMLParser, foundCharacters string: String)
    {
        // Parsing is based on handling of classes
        guard let classID = currentXMLClass else {return}
        switch classID
        {
        case kStringSearchResultClassID:
            guard let _ = currentResultContentString else {return}
            currentResultContentString! += string
            
        case kStringSearchResultsCountClassID:
            if let count = parseResultsCountFromString(string)
            {
                resultsNumber = count
            }
            break
            
        default:
            break
        }
    }
    
    func parser(parser: NSXMLParser, parseErrorOccurred parseError: NSError)
    {
        if !cancelled
        {
            delegate?.parseErrorOccured(parseError)
        }
    }
    
    func parser(parser: NSXMLParser, resolveExternalEntityName name: String, systemID: String?) -> NSData?
    {
        print("Resolve external entity \(name) \(systemID)")
        return NSData()
    }
    
    func parser(parser: NSXMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?)
    {
        print("Found unparsed item \(name)")
    }
    
    func parseResultsCountFromString(stringWithCount: String) -> Int64?
    {
        let items = stringWithCount.componentsSeparatedByString(" ")
        if items.count == 0 {return nil}
        var count: Int64?
        for item in items
        {
            var cleanedString = item.stringByReplacingOccurrencesOfString(",", withString: "")
            cleanedString = cleanedString.stringByReplacingOccurrencesOfString(".", withString: "")
            let parsedCount = Int64(cleanedString)
            if parsedCount > 0
            {
                count = parsedCount
                break
            }
        }
        return count
    }
}
