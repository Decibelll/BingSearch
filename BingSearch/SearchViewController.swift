//
//  SearchViewController.swift
//  BingSearch
//
//  Created by Sergii Nesteruk on 8/12/16.
//  Copyright © 2016 sergeynesteruk. All rights reserved.
//

import UIKit
import Foundation

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate
{
    @IBOutlet weak var searchTypeSegmentedControl: UISegmentedControl!
    @IBOutlet weak var searchTableView: UITableView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var searchTextField: UITextField!
    
    
    private var searchAgent: BingSearch!
    private var searchResults = [ResultModel]()
    private var searchOperation = NSBlockOperation(block: {})
    private var currentSearchPhrase: String?
    private var searching = false
    private var newSearch = true
    private var searchResultsCount: Int64?
    private var canDoNextSearch = false
    private var trackingKeyboardHeight = false
    
    deinit
    {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        searchTableView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
        searchTableView.scrollIndicatorInsets = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
        
        let searchCallback: SearchCallback = {[weak self](items, searchCount, errorInfo) in
            guard let strongSelf = self else {return}
            dispatch_async(dispatch_get_main_queue()){
                strongSelf.updateInterfaceWithSearchResult(items, searchCount: searchCount, errorDescription: errorInfo)
            }
        }
        searchAgent = BingSearch(searchCallback: searchCallback)
        
        // Show info label, hide table
        searchTableView.hidden = true
        infoLabel.hidden = false
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SearchViewController.keyboardDidShow(_:)), name: UIKeyboardDidShowNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SearchViewController.keyboardWillHide(_:)), name: UIKeyboardWillHideNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(SearchViewController.keyboardWillChangeFrame(_:)), name: UIKeyboardWillChangeFrameNotification, object: nil)
    }
    
    override func didRotateFromInterfaceOrientation(fromInterfaceOrientation: UIInterfaceOrientation)
    {
        searchTableView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
        searchTableView.scrollIndicatorInsets = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?)
    {
        if segue.identifier == "OpenDetailController"
        {
            guard let searchResult = sender as? ResultModel else {return}
            guard let detailController = segue.destinationViewController as? DetailViewConroller else {return}
            detailController.link = searchResult.url
        }
    }
    
    func updateInterfaceWithSearchResult(foundItems: [ResultModel], searchCount: Int64?, errorDescription: String?)
    {
        searching = false
        if let error = errorDescription
        {
            if newSearch
            {
                searchResults = []
                infoLabel.text = error
                infoLabel.hidden = false
                searchTableView.hidden = true
                currentSearchPhrase = nil
                return
            }
            else
            {
                canDoNextSearch = false
                searchTableView.reloadData()
                return
            }
        }
        
        if newSearch
        {
            // No results found
            if foundItems.count == 0
            {
                searchResults = []
                searchTableView.hidden = true
                infoLabel.text = "No results found"
                infoLabel.hidden = false
                return
            }
            
            searchResultsCount = searchCount
            searchResults = foundItems
            searchTableView.reloadData()
        }
        else
        {
            searchResults += foundItems
            searchTableView.reloadData()
        }
        
        if shouldSearchImages() && foundItems.count == 28
        {
            canDoNextSearch = true
        }
        else if !shouldSearchImages() && foundItems.count == 10
        {
            canDoNextSearch = true
        }
        else
        {
            canDoNextSearch = false
        }
    }
    
    func doNewSearch(rawText: String?)
    {
        guard var textToSearch = rawText else
        {
            searchResults = []
            searchTableView.hidden = true
            infoLabel.text = "Enter search key"
            infoLabel.hidden = false
            currentSearchPhrase = nil
            return
        }
        
        textToSearch = textToSearch.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        guard textToSearch.characters.count > 2 else {
            searchResults = []
            searchTableView.hidden = true
            infoLabel.text = "Enter search key (min 3 characters)"
            infoLabel.hidden = false
            currentSearchPhrase = nil
            return
        }
        
        if textToSearch != currentSearchPhrase
        {
            currentSearchPhrase = textToSearch
            searching = true
            newSearch = true
            searchResults = []
            searchTableView.reloadData()
            searchTableView.hidden = false
            infoLabel.hidden = true
            searchResultsCount = nil
            searchAgent.search(textToSearch, searchImages: shouldSearchImages(), firstItemNumber: 1)
        }
    }
    
    func doNextSearch()
    {
        if let searchText = currentSearchPhrase
        {
            searching = true
            newSearch = false
            searchAgent.search(searchText, searchImages: shouldSearchImages(), firstItemNumber: searchResults.count + 1)
            dispatch_async(dispatch_get_main_queue()) {
                self.searchTableView.reloadData()
            }
        }
    }
    
    func shouldSearchImages() -> Bool
    {
        return searchTypeSegmentedControl.selectedSegmentIndex == 1
    }
    
    @IBAction func segmentedControlChanged(sender: AnyObject)
    {
        currentSearchPhrase = nil
        doNewSearch(searchTextField.text)
    }
    
    // MARK: UITableViewDataSource and UITableViewDelegate methods
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return searchResults.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell
    {
        var cell: UITableViewCell
        let searchResult = searchResults[indexPath.row]
        if shouldSearchImages() // Image
        {
            let imageCell = tableView.dequeueReusableCellWithIdentifier("ImageTableCell", forIndexPath: indexPath) as! ImageSearchResultTableCell
            imageCell.searchImageView.loadImageFromURL(searchResult.imageURL!)
            imageCell.searchTitle.text = searchResult.title
            imageCell.searchSubtitle.text = searchResult.url.host
            cell = imageCell
        }
        else // WEB
        {
            cell = tableView.dequeueReusableCellWithIdentifier("TableCell", forIndexPath: indexPath)
            cell.textLabel?.text = searchResult.title
            cell.detailTextLabel?.text = searchResult.url.host
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat
    {
        if shouldSearchImages() // Image
        {
            return 100
        }
        else // WEB
        {
            return 55
        }
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        guard let count = searchResultsCount else {return nil}
        return String(count) + " results found"
    }
    
    func tableView(tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        return nil
    }
    
    func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        guard searching else {return nil}
        let container = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 44))
        let spinner = UIActivityIndicatorView(activityIndicatorStyle: .Gray)
        spinner.center = CGPoint(x: container.frame.width / 2, y: container.frame.height / 2)
        container.addSubview(spinner)
        spinner.startAnimating()
        return container
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath)
    {
        if indexPath.row == (searchResults.count - 1)
        {
            if canDoNextSearch && !searching
            {
                doNextSearch()
            }
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath)
    {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        searchTextField.resignFirstResponder()
        let searchResult = searchResults[indexPath.row]
        performSegueWithIdentifier("OpenDetailController", sender: searchResult)
    }
    
    // MARK: UITextFieldDelegate
    func textFieldShouldReturn(textField: UITextField) -> Bool
    {
        searchOperation.cancel()
        doNewSearch(textField.text)
        textField.resignFirstResponder()
        return true
    }
    
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool
    {
        searchOperation.cancel()
        let textToSearch = (textField.text! as NSString).stringByReplacingCharactersInRange(range, withString: string)
        let newOperation = NSBlockOperation { [weak self] in
            guard let strongSelf = self else {return}
            strongSelf.doNewSearch(textToSearch)
        }
        searchOperation = newOperation
        delay(2, queue: dispatch_get_main_queue()) {
            newOperation.start()
        }
        return true
    }
    
    // MARK: Notifications handlers
    func keyboardDidShow(notification: NSNotification)
    {
        if let finalRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue(), startRect = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue()
        {
            // Do not change insets on iPad when keyboard is undocked or split
            if abs(finalRect.maxY - startRect.minY) > 10
            {
                return
            }
            
            searchTableView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: finalRect.height, right: 0)
            searchTableView.scrollIndicatorInsets = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: finalRect.height, right: 0)
            trackingKeyboardHeight = true
        }
    }
    
    func keyboardWillHide(notification: NSNotification)
    {
        searchTableView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
        searchTableView.scrollIndicatorInsets = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: 44, right: 0)
        trackingKeyboardHeight = false
    }
    
    func keyboardWillChangeFrame(notification: NSNotification)
    {
        if trackingKeyboardHeight
        {
            guard let finalRect = (notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.CGRectValue() else {return}
            searchTableView.contentInset = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: finalRect.height, right: 0)
            searchTableView.scrollIndicatorInsets = UIEdgeInsets(top: topLayoutGuide.length, left: 0, bottom: finalRect.height, right: 0)
        }
    }
}

func delay(delay: Double, queue: dispatch_queue_t, closure: ()->())
{
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        queue,
        closure
    )
}

