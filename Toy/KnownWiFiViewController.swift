//
//  MyWiFiNetsViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 3/22/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//
//  Wi-fi networks the Toy knows about (successfully connected in the past)
//  Show networks / connect network / forget network

import Foundation
import UIKit

var knownNetworks = [WiFiItems]()

// MARK: Table View Cell Prototype **********************************************************************************
//-------------------------------------------------------
class KnownWiFiViewCell: UITableViewCell{
    
    // MARK: Outlets
    @IBOutlet var NetworkNameLabel: UILabel!
    @IBOutlet var ProtectedImage: UIImageView!
    @IBOutlet var RSSIImage: UIImageView!
}

// MARK: Known Wi-Fi Networks Table View Controller ******************************************************************
//-------------------------------------------------------
class KnownWiFiTableViewController: UITableViewController, UIGestureRecognizerDelegate {
    
    var myAlert : UIAlertController? = nil


    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralController.knownWiFiViewController = self
        
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(KnownWiFiTableViewController.respondToSwipeGesture(_:)))
        swipeDown.direction = UISwipeGestureRecognizerDirection.down
        WiFiTableView.addGestureRecognizer(swipeDown)
        swipeDown.delegate = self
        WiFiTableView.delegate = self
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabBarController?.navigationItem.title = "Known"
        if  centralController.visibleWiFiViewController == nil || centralController.getWiFiStatus() != ToyWiFiStatus.connecting {
            refreshNetworks(15)
        } else if centralController.visibleIsFetching == true {
            centralController.knownIsFetching = true
            if tableView.tableFooterView == nil{
                let pagingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
                pagingSpinner.startAnimating()
                pagingSpinner.hidesWhenStopped = true
                tableView.tableFooterView = pagingSpinner
            }
        }
        WiFiTableView.reloadData()
    }
    
    //-------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
    }
    
    
    // MARK: Outlets
    @IBOutlet var WiFiTableView: UITableView!
    
    // MARK: Functions
    //-----------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if (indexPath as NSIndexPath).section == 1{
            _ = self.navigationController?.popViewController(animated: true)
            _ = centralController.connectWiFiNetwork((indexPath as NSIndexPath).row, password: "")
        }
    }
    
    //-----------------------------------
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // the cells you would like the actions to appear needs to be editable
        return true
    }
    
    //-----------------------------------
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let forget = UITableViewRowAction(style: .normal, title: "Forget") { action, index in
            tableView.setEditing(false, animated: true)
            centralController.forgetWiFiNetwork((indexPath as NSIndexPath).row)
            self.WiFiTableView.reloadData()
        }
        forget.backgroundColor = MY_RED_COLOR
        
        return [forget]
    }
    
    //-----------------------------------
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }
    
    //-------------------------------------------------------
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            return "Known Wi-Fi Networks"
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return knownNetworks.count
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "KnownWiFiViewCell", for: indexPath) as! KnownWiFiViewCell
        
        objc_sync_enter(knownNetworks)
        defer { objc_sync_exit(knownNetworks) }
        
        cell.NetworkNameLabel.text = knownNetworks[(indexPath as NSIndexPath).row].SSID
        
        cell.ProtectedImage.isHidden = false
        if(knownNetworks[(indexPath as NSIndexPath).row].isProtected == true){
            cell.ProtectedImage.image = UIImage(named: "Lock")
        } else {
            cell.ProtectedImage.image = UIImage(named: "Unlock")
        }
        
        if knownNetworks[(indexPath as NSIndexPath).row].status == WiFiNetworkStatus.visible{
            cell.RSSIImage.isHidden = false
           
            let rssi = -knownNetworks[(indexPath as NSIndexPath).row].RSSI
            
            if rssi <= 40 {
                cell.RSSIImage.image = UIImage(named: "WiFiFull")
            } else if rssi  > 40 && rssi <= 60 {
                cell.RSSIImage.image = UIImage(named: "WiFiHalf")
            } else if rssi > 60 {
                cell.RSSIImage.image = UIImage(named: "WiFiMin")
            }
        } else {
            cell.RSSIImage.isHidden = true
        }
        return cell
    }
    
    //-------------------------------------------------------
    func gestureRecognizer(_ swipeDown: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer:UIGestureRecognizer) -> Bool {
        return true
    }
    
    //-------------------------------------------------------
    @objc func respondToSwipeGesture(_ recognizer: UIGestureRecognizer){
        if  centralController.getWiFiStatus() == ToyWiFiStatus.idle || centralController.getWiFiStatus() == ToyWiFiStatus.fetching{
            if centralController.knownIsFetching == false {
                refreshNetworks(0)
                tableView.reloadData()
            }
        }
    }
    
    //-------------------------------------------------------
    func refreshNetworks(_ timeout: Double){
        if centralController.getKnownWiFiNetworks(timeout) == true && tableView.tableFooterView == nil {
            let pagingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            pagingSpinner.startAnimating()
            pagingSpinner.hidesWhenStopped = true
            tableView.tableFooterView = pagingSpinner
            knownNetworks.removeAll()
            tableView.reloadData()
            _ = centralController.getVisibleWiFiNetworks(0)
        }
    }
    
    //-----------------------------------
    func networkUpdated (_ isFinished : Bool, response : UInt8){
        if isFinished == true {
            tableView.tableFooterView = nil
            
        }
        switch response {
            
        case 2:
            displayMyAlertMessage("Unable to connect. SSID is incorrect.")
            break
        case 3:
            displayMyAlertMessage("Unable to connect. Password is incorrect.")
            break
        case 5:
            displayMyAlertMessage("Unable to connect. Password is incorrect.")
            break
        case 6:
            displayMyAlertMessage("Unable to connect to KiQ cloud server. Probably some DNS problem.")
            break
        case 7:
            displayMyAlertMessage("Unable to connect to KiQ cloud server. Probably beacause of a Captive Portal.")
            break
        case 100:
            displayMyAlertMessage("Unable to get list of known Wi-Fi networks. Please try again")
            break
        case 101:
            displayMyAlertMessage("Unable to connect to Wi-fi network")
            break
        default:
            break
        }
        self.tableView.reloadData()
    }
    
    //----------------------------------------------------
    func isModal() -> Bool {
        if self.presentingViewController != nil && self.tabBarController?.selectedIndex == 0 {
            return true
        }
        return false
    }
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {
        if isModal() == true {
            let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
            let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil);
            myAlert.addAction(okAction);
            self.present(myAlert , animated: true, completion: nil)
        }
    }
}
