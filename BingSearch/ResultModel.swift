//
//  ResultModel.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/13/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation

struct ResultStruct
{
    var title: String?
    var url: NSURL?
    var imageURL: NSURL?
}

class ResultModel
{
    let title: String
    let url: NSURL
    let imageURL: NSURL?
    
    init?(resultStruct: ResultStruct, isImageResult: Bool = false)
    {
        guard let title = resultStruct.title where title.characters.count > 0 else {return nil}
        self.title = title
        
        guard let url = resultStruct.url else {return nil}
        self.url = url
        
        guard let imageURL = resultStruct.imageURL where isImageResult else
        {
            self.imageURL = nil
            return
        }
        self.imageURL = imageURL
    }
}