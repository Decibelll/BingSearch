//
//  UIImageView+AsyncImageLoading.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/15/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import Foundation
import UIKit

extension UIImageView
{
    func loadImageFromURL(url: NSURL, completion: (()->())? = nil)
    {
//        let placeholderImage = UIImage(named: "preview_icon")
        let placeholderImage: UIImage? = nil
//        let spinnerTag = 1001
//        if viewWithTag(spinnerTag) == nil
//        {
//            let spinner = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
//            spinner.tag = spinnerTag
//            addSubview(spinner)
//            spinner.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
//            spinner.startAnimating()
//        }
//        image = placeholderImage
        let timestamp = NSDate.timeIntervalSinceReferenceDate()
        RequestTimeStampsManager.sharedInstance[self] = timestamp
        let currentSessionTask = NSURLSession.sharedSession().dataTaskWithURL(url) {[weak self](data, response, error) in
            guard let strongSelf = self else {return}
            guard error == nil else
            {
                if RequestTimeStampsManager.sharedInstance.isRequestStillValid(strongSelf, timestamp: timestamp)
                {
                    dispatch_async(dispatch_get_main_queue()) {
                        strongSelf.image = placeholderImage
//                        if let spinner = strongSelf.viewWithTag(spinnerTag)
//                        {
//                            spinner.removeFromSuperview()
//                        }
                        completion?()
                    }
                }
                return
            }
            
            guard let data = data else
            {
                if RequestTimeStampsManager.sharedInstance.isRequestStillValid(strongSelf, timestamp: timestamp)
                {
                    dispatch_async(dispatch_get_main_queue()) {
                        strongSelf.image = placeholderImage
//                        if let spinner = strongSelf.viewWithTag(spinnerTag)
//                        {
//                            spinner.removeFromSuperview()
//                        }
                        completion?()
                    }
                }
                return
            }
            
            if let image = UIImage(data: data)
            {
                if RequestTimeStampsManager.sharedInstance.isRequestStillValid(strongSelf, timestamp: timestamp)
                {
                    dispatch_async(dispatch_get_main_queue()) {
                        strongSelf.image = image
//                        if let spinner = strongSelf.viewWithTag(spinnerTag)
//                        {
//                            spinner.removeFromSuperview()
//                        }
                        completion?()
                    }
                }
            }
            else
            {
                if RequestTimeStampsManager.sharedInstance.isRequestStillValid(strongSelf, timestamp: timestamp)
                {
                    dispatch_async(dispatch_get_main_queue()) {
                        strongSelf.image = placeholderImage
//                        if let spinner = strongSelf.viewWithTag(spinnerTag)
//                        {
//                            spinner.removeFromSuperview()
//                        }
                        completion?()
                    }
                }
            }
        }
        
        currentSessionTask.resume()
    }
}

class RequestTimeStampsManager
{
    static let sharedInstance = RequestTimeStampsManager()
    
    private var timeStampsDictionary = Dictionary<UIImageView, NSTimeInterval>()
    
    subscript(index: UIImageView) -> NSTimeInterval? {
        get
        {
            return timeStampsDictionary[index]
        }
        set(newValue)
        {
            if let newValue = newValue
            {
                timeStampsDictionary[index] = newValue
            }
            else
            {
                timeStampsDictionary.removeValueForKey(index)
            }
        }
    }
    
    func isRequestStillValid(key: UIImageView, timestamp: NSTimeInterval) -> Bool
    {
        guard let storedTimestamp = timeStampsDictionary[key] else {return false}
        return abs(timestamp - storedTimestamp) < DBL_EPSILON
    }
}