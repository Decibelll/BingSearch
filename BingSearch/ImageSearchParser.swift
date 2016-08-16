//
//  ImageSearchParser.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/14/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation


class ImageSearchParser: NSObject, NSXMLParserDelegate
{
    weak var delegate: ParserDelegate?
    
    private var parser: NSXMLParser!
    private var currentResult: ResultStruct?
    private var resultsCountString: String?
    private var parsedItems = [ResultModel]()
    private var currentXMLClassElement: String?
    private var currentXMLClass: String?
    private var cancelled = false
    private var recognizedClasses: Set<String>
    
    private let kImageThumbClassID = "cico"
    private let kImageThumbElementName = "img"
    private let kImageLinkClassID = "tit"
    private let kImageDescriptionClassID = "des"
    
    init?(searchPhrase: String, parserDelegate: ParserDelegate, startItem: Int = 0)
    {
        recognizedClasses = [kImageThumbClassID, kImageLinkClassID, kImageDescriptionClassID]
        
        delegate = parserDelegate
        let trimmedSearchPhrase = searchPhrase.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        guard trimmedSearchPhrase.characters.count > 0 else {return nil}
        
        let escapedPhrase = searchPhrase.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet());
        guard let escapedSearchPhrase = escapedPhrase else {return nil}
        
        let requestString = "https://www.bing.com/images/search?q=" + escapedSearchPhrase + "&first=" + String(startItem)
        let url = NSURL(string: requestString)
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
        if let classID = attributeDict["class"] where recognizedClasses.contains(classID)
        {
            currentXMLClassElement = elementName
            currentXMLClass = classID
        }
        
        // Parsing is based on handling of classes
        guard let classID = currentXMLClass else {return}
        
        switch classID
        {
        case kImageThumbClassID:
            if let _ = currentResult
            {
                if elementName == kImageThumbElementName
                {
                    if let urlString = attributeDict["src"]
                    {
                        currentResult!.imageURL = NSURL(string: urlString)
                    }
                }
            }
            else
            {
                currentResult = ResultStruct()
            }
            
        case kImageLinkClassID:
            if let _ = currentResult
            {
                if let urlString = attributeDict["href"], url = NSURL(string: urlString)
                {
                    currentResult!.url = url
                }
            }
            
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
        case kImageDescriptionClassID:
            guard let _ = currentResult else {return}
            
            if let result = ResultModel(resultStruct: currentResult!, isImageResult: false)
            {
                parsedItems.append(result)
            }
            currentResult = nil
            
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
        case kImageDescriptionClassID:
            guard let _ = currentResult else {return}
            currentResult!.title = string
            
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
}