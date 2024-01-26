//
//  WiFiSettingsViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 2/15/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit


public enum WiFiNetworkStatus {
    case known
    case connecting
    case unknown
    case disconnecting
    case visible
}

// MARK: prototype **********************************************************************************
//-------------------------------------------------------
class WiFiItems {
    
    // MARK: Properties
    var SSID:           String!
    var RSSI:           Int8!
    var isProtected:    Bool!
    var status:         WiFiNetworkStatus
    
    // MARK: Initialization
    init?(SSID: String, RSSI: Int8, isProtected: Bool, status: WiFiNetworkStatus) {
        // Initialize stored properties.
        self.SSID = SSID
        self.RSSI = RSSI
        self.isProtected = isProtected
        self.status = status
    }
}

var visibleNetworks = [WiFiItems]()

// MARK: Table View Cell Prototype **********************************************************************************
//-------------------------------------------------------
class VisibleWiFiViewCell: UITableViewCell{
    
    // MARK: Properties
    @IBOutlet var networkName: UILabel!
    @IBOutlet var RSSIimg: UIImageView!
    @IBOutlet var ProtectedImg: UIImageView!
    @IBOutlet weak var statusImg: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
}

// MARK: Known Wi-Fi Networks Table View Controller ******************************************************************
//-------------------------------------------------------
class VisibleWiFiViewTableViewController: UITableViewController, UIGestureRecognizerDelegate{
    
    // MARK: Properties
    var myAlert : UIAlertController? = nil
    
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralController.visibleWiFiViewController = self
        let swipeDown = UISwipeGestureRecognizer(target: self, action: #selector(VisibleWiFiViewTableViewController.respondToSwipeGesture(_:)))
        swipeDown.direction = UISwipeGestureRecognizerDirection.down
        self.WiFiTableView.addGestureRecognizer(swipeDown)
        swipeDown.delegate = self
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tabBarController?.navigationItem.title = "Visible"
        
        if  centralController.getWiFiStatus() == ToyWiFiStatus.idle || centralController.getWiFiStatus() == ToyWiFiStatus.fetching{
            _ = centralController.getVisibleWiFiNetworks(15)
        }
        WiFiTableView.reloadData()
    }
    
    //-------------------------------------------------------
    @IBOutlet var WiFiTableView: UITableView!
    
    
    //-------------------------------------------------------
    func gestureRecognizer(_ swipeDown: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith shouldRecognizeSimultaneouslyWithGestureRecognizer:UIGestureRecognizer) -> Bool {
        return true
    }
    
    //-------------------------------------------------------
    @objc func respondToSwipeGesture(_ recognizer: UIGestureRecognizer){
         if  centralController.getWiFiStatus() == ToyWiFiStatus.idle || centralController.getWiFiStatus() == ToyWiFiStatus.fetching{
            if centralController.visibleIsFetching == false {
                _ = centralController.getVisibleWiFiNetworks(0)
                WiFiTableView.reloadData()
            }
        }
    }
    
    //-------------------------------------------------------
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Choose network..."
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visibleNetworks.count
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        objc_sync_enter(visibleNetworks)
        defer { objc_sync_exit(visibleNetworks) }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "VisibleWiFiViewCell", for: indexPath) as! VisibleWiFiViewCell
        let item = visibleNetworks[(indexPath as NSIndexPath).row]
        cell.networkName.text = item.SSID
        
        if cell.networkName.text == "Other..." && item.RSSI == 1{
            cell.ProtectedImg.isHidden = true
            cell.RSSIimg.isHidden = true
        } else {
            cell.RSSIimg.isHidden = false
            cell.ProtectedImg.isHidden = false
        }
        
        if (indexPath as NSIndexPath).row == 0 && centralController.visibleIsFetching{
            let pagingSpinner = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            pagingSpinner.startAnimating()
            pagingSpinner.hidesWhenStopped = true
            tableView.tableFooterView = pagingSpinner
        }
        
        if(item.isProtected == true){
            cell.ProtectedImg.image = UIImage(named: "Lock")
        } else {
            cell.ProtectedImg.image = UIImage(named: "Unlock")
        }
        
        if item.RSSI == 1 {
            cell.RSSIimg.isHidden = true
        } else {
            cell.RSSIimg.isHidden = false
            let rssi = -item.RSSI
            if rssi <= 40 {
                cell.RSSIimg.image = UIImage(named: "WiFiFull")
            } else if rssi  > 40 && rssi <= 60 {
                cell.RSSIimg.image = UIImage(named: "WiFiHalf")
            } else if rssi > 60 {
                cell.RSSIimg.image = UIImage(named: "WiFiMin")
            }
        }
        
        switch item.status {
        case WiFiNetworkStatus.known:
            cell.statusImg.isHidden = false
            cell.activityIndicator.stopAnimating()
            break
        case WiFiNetworkStatus.connecting:
            cell.statusImg.isHidden = true
            cell.activityIndicator.startAnimating()
            break
        case WiFiNetworkStatus.unknown:
            cell.statusImg.isHidden = true
            cell.activityIndicator.stopAnimating()
            break
        case WiFiNetworkStatus.disconnecting:
            cell.statusImg.isHidden = true
            cell.activityIndicator.startAnimating()
            break
        default:
            cell.statusImg.isHidden = true
            cell.activityIndicator.stopAnimating()
            break
        }
        
        return cell
    }
    
    ///-----------------------------------
    override func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
       
        objc_sync_enter(visibleNetworks)  // Lock Visible
        defer { objc_sync_exit(visibleNetworks) }
        
        if visibleNetworks[(indexPath as NSIndexPath).row].status == WiFiNetworkStatus.known {
            let forget = UITableViewRowAction(style: .normal, title: "Forget") { action, index in
                tableView.setEditing(false, animated: true)
                
                objc_sync_enter(knownNetworks) // Lock Known
                defer { objc_sync_exit(knownNetworks) }
                
                for i in 0 ..< knownNetworks.count {
                    if knownNetworks[i].SSID == visibleNetworks[(indexPath as NSIndexPath).row].SSID && knownNetworks[i].RSSI == visibleNetworks[(indexPath as NSIndexPath).row].RSSI {
                        centralController.forgetWiFiNetwork(i)
                        break
                    }
                }
                tableView.reloadData()
            }
            forget.backgroundColor = MY_RED_COLOR
            
            return [forget]
        } else {
            let connect = UITableViewRowAction(style: .normal, title: "Add") { action, index in
                tableView.setEditing(false, animated: true)
                if centralController.getWiFiStatus() != ToyWiFiStatus.connecting {
                    if visibleNetworks[(indexPath as NSIndexPath).row].SSID == "Other..." && visibleNetworks[(indexPath as NSIndexPath).row].RSSI == 1 {
                        let otherWiFiViewController = self.storyboard?.instantiateViewController(withIdentifier: "OtherWiFiViewController") as? OtherWiFiViewController
                        otherWiFiViewController?.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                        self.navigationController?.pushViewController(otherWiFiViewController!, animated:true)
                    } else {
                        if visibleNetworks[(indexPath as NSIndexPath).row].isProtected == false {
                            _ = centralController.connectWiFiNetwork((indexPath as NSIndexPath).row, password: "")
                        } else {
                            let passwordViewController = self.storyboard?.instantiateViewController(withIdentifier: "WiFiPasswordViewController") as? WiFiPasswordViewController
                            passwordViewController!.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                            
                            passwordViewController!.setWiFiSettings ((indexPath as NSIndexPath).row)
                            self.navigationController?.pushViewController(passwordViewController!, animated:true)
                        }
                    }
                } else {
                    self.displayMyAlertMessage("Connection is in progress. Please wait.")
                }
            }
            connect.backgroundColor = UIColor(red: 0, green: 122/255, blue: 255/255, alpha: 1)
            return [connect]
        }
    }
    //-----------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        objc_sync_enter(visibleNetworks)
        defer { objc_sync_exit(visibleNetworks) }
        
        if visibleNetworks[(indexPath as NSIndexPath).row].status != WiFiNetworkStatus.known {
            if centralController.getWiFiStatus() != ToyWiFiStatus.connecting {
                if visibleNetworks[(indexPath as NSIndexPath).row].SSID == "Other..." && visibleNetworks[(indexPath as NSIndexPath).row].RSSI == 1 {
                    let otherWiFiViewController = storyboard?.instantiateViewController(withIdentifier: "OtherWiFiViewController") as? OtherWiFiViewController
                    otherWiFiViewController?.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                    navigationController?.pushViewController(otherWiFiViewController!, animated:true)
                } else {
                    if visibleNetworks[(indexPath as NSIndexPath).row].isProtected == false {
                        _ = centralController.connectWiFiNetwork((indexPath as NSIndexPath).row, password: "")
                    } else {
                        let passwordViewController = storyboard?.instantiateViewController(withIdentifier: "WiFiPasswordViewController") as? WiFiPasswordViewController
                        passwordViewController!.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                        
                        passwordViewController!.setWiFiSettings ((indexPath as NSIndexPath).row)
                        navigationController?.pushViewController(passwordViewController!, animated:true)
                    }
                }
            } else {
                displayMyAlertMessage("Connection is in progress. Please wait.")
            }
        }
    }
    
    //-------------------------------------------------------
    func networkUpdated (_ isFinished : Bool, response : UInt8){
        if isFinished == true {
            self.tableView.tableFooterView = nil
        }
        switch response {
            
        case 2:
            displayMyAlertMessage("Unable to connect. SSID is incorrect.")
            break
        case 3:
            displayMyAlertMessage("Unable to connect. Password is incorrect.")
        case 32:
            displayMyAlertMessage("Unable to connect. Incorrect SSID or Password")
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
            displayMyAlertMessage("Unable to get list of visible Wi-Fi networks. Please try again")
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
        if self.presentingViewController != nil && self.tabBarController?.selectedIndex == 1 {
            return true
        }
        
        return false
    }
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {   if isModal() == true {
            let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
            let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil);
            myAlert.addAction(okAction);
            self.present(myAlert , animated: true, completion: nil)
        }
    }
}


// MARK: Enter password for a secured network View Controller ******************************************************************
//-------------------------------------------------------
class WiFiPasswordViewController: UIViewController, UITextFieldDelegate{
    
    var index : Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        objc_sync_enter(visibleNetworks)
        defer { objc_sync_exit(visibleNetworks) }
        
        HeaderLabel.text = "Enter the password for " + visibleNetworks[index].SSID
        PasswordTextField.becomeFirstResponder()
        PasswordTextField.delegate = self
        PasswordTextField.text = ""
    }
    
    @IBAction func joinTapped(_ sender: AnyObject) {
        if ((PasswordTextField.text?.isEmpty) != true) {
            if PasswordTextField.text!.lengthOfBytes(using: String.Encoding.utf8) < 8 {
                displayMyAlertMessage("Password must be at least 8 characters long");
            } else {
                _ = centralController.connectWiFiNetwork(index, password: PasswordTextField.text!)
                _ = navigationController?.popToViewController(centralController.wifiSettingsTabBarController!, animated: true)
            }
        } else {
            displayMyAlertMessage("Please enter the password");
        }
    }
    
    
    @IBOutlet var PasswordTextField: UITextField!
    @IBOutlet var HeaderLabel: UILabel!
    
    //----------------------------------------------------
    func setWiFiSettings (_ index : Int ){
        self.index = index
    }
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {
        let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil);
        myAlert.addAction(okAction);
        self.present(myAlert , animated: true, completion: nil)
    }
    
    //-------------------------------------------------------
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        if string == "\n" {
            if textField.text!.isEmpty == false {
                if textField.text!.lengthOfBytes(using: String.Encoding.utf8) < 8 {
                    displayMyAlertMessage("Password must be at least 8 characters long");
                } else {
                    _ = centralController.connectWiFiNetwork(index, password: PasswordTextField.text!)
                    _ = self.navigationController?.popViewController(animated: true)
                    _ = self.navigationController?.popToViewController(centralController.knownWiFiViewController!, animated: true)
                    textField.resignFirstResponder()
                }
            } else {
                displayMyAlertMessage("Please enter the password");
            }
        }
        let maxLength = 59
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }

}

// MARK: Connect Other Wi-Fi network View Controller ******************************************************************
//-------------------------------------------------------
class OtherWiFiViewController: UIViewController, UITextFieldDelegate{
    
    var SSID: String?
    var RSSI: UInt8 = 0
    var isProtected: UInt8 = 0
    var atIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let joinButton = UIBarButtonItem(title: "Join", style: UIBarButtonItemStyle.plain, target: self, action: #selector(OtherWiFiViewController.joinTapped))
        navigationItem.rightBarButtonItem = joinButton
        title = "Other"
        SSIDTextField.delegate = self
        SSIDTextField.tag = 1
        PasswordTextField.delegate = self
        PasswordTextField.tag = 2
    }
    
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SSIDTextField.becomeFirstResponder()
    }
    
    //-------------------------------------------------------
    @IBOutlet var HeaderLabel: UILabel!
    @IBOutlet var SSIDTextField: UITextField!
    @IBOutlet var PasswordTextField: UITextField!
    @IBOutlet var PasswordView: UIView!
    @IBOutlet var IsProtectedSwitch: UISwitch!

    //-------------------------------------------------------
    @IBAction func isProtectedChanged(_ sender: AnyObject) {
        if IsProtectedSwitch.isOn {
            PasswordView.isHidden = false
            SSIDTextField.returnKeyType = UIReturnKeyType.done
            SSIDTextField.resignFirstResponder()
            SSIDTextField.becomeFirstResponder()
        } else {
            PasswordView.isHidden = true
            SSIDTextField.returnKeyType = UIReturnKeyType.join
            SSIDTextField.resignFirstResponder()
            SSIDTextField.becomeFirstResponder()
        }
    }
    
    //-------------------------------------------------------
    @objc func joinTapped() {
        if (SSIDTextField.text?.isEmpty) == true {
            displayMyAlertMessage("Please enter the network name");
            return
        }
        if IsProtectedSwitch.isOn && (PasswordTextField.text?.isEmpty) == true {
            displayMyAlertMessage("Please enter password");
            return
        }
        
        if IsProtectedSwitch.isOn && (PasswordTextField.text?.lengthOfBytes(using: String.Encoding.utf8))! < 8 {
            displayMyAlertMessage("Password must be at least 8 characters long ");
            return
        }
        
        objc_sync_enter(visibleNetworks)
        defer { objc_sync_exit(visibleNetworks) }
        
        let network : WiFiItems = WiFiItems(SSID: SSIDTextField.text!, RSSI: 1, isProtected: IsProtectedSwitch.isOn, status: WiFiNetworkStatus.unknown)!
        visibleNetworks.removeLast()
        visibleNetworks.append(network)
        
        if centralController.connectWiFiNetwork(visibleNetworks.count - 1, password: PasswordTextField.text!) != true {
            visibleNetworks.removeLast()
            visibleNetworks.append(WiFiItems(SSID: "Other...", RSSI: 1, isProtected: false, status: WiFiNetworkStatus.unknown)!)
        }
        _ = navigationController?.popToViewController(centralController.wifiSettingsTabBarController!, animated: true)
    }
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {
        let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default, handler: nil);
        myAlert.addAction(okAction);
        self.present(myAlert , animated: true, completion: nil)
    }
    
    //-------------------------------------------------------
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        if string == "\n" {
            if textField.tag == 1  {
                if SSIDTextField.text?.isEmpty == true {
                  displayMyAlertMessage("Please enter the network name")
                } else {
                    if IsProtectedSwitch.isOn == false {
                        textField.resignFirstResponder()
                        joinTapped()
                    } else {
                        PasswordTextField.becomeFirstResponder()
                    }
                }
            } else {
                if (PasswordTextField.text?.lengthOfBytes(using: String.Encoding.utf8))! < 8 {
                    displayMyAlertMessage("Password must be at least 8 characters long");
                } else {
                    joinTapped()
                    textField.resignFirstResponder()
                }
            }
            
        }
        
        var maxLength = 59
        if textField.tag == 1 {
            maxLength = 18
        }
        let currentString: NSString = textField.text! as NSString
        let newString: NSString = currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
}


