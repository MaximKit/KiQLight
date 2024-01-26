//
//  ToySettingsViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 2/2/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit

//-----------------------------------------------
// MARK ToySettingsTabBarController
class WiFiSettingsTabBarController: UITabBarController, UIPageViewControllerDelegate {
    
    var recentsTabBarItem: UITabBarItem = UITabBarItem()
    
    //--------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        centralController.wifiSettingsTabBarController = self
    }
    
    //-----------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
    }
}

//-------------------------------------------------------
class ToySettingsTableViewController: UITableViewController, UITextFieldDelegate{
    
    // MARK: Properties
    var silentSettings : SilentTimeSettings?
    let timeFormatter = DateFormatter()
    var toySilentSettingsViewController: ToySilentSettingsViewController?
    var silentSettingsChanged: Bool = false
    
    // MARK: Functions
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        centralController.toySettingsViewController = self
        timeFormatter.timeStyle = DateFormatter.Style.short
        SoundVouleSlider.selectedBarColor = MY_GREEN_COLOR
        SoundVouleSlider.unselectedBarColor = UIColor(red: 200/255, green: 200/255, blue: 200/255, alpha: 1)
        SoundVouleSlider.markWidth = 1.0
        SoundVouleSlider.markColor = UIColor.white
        SoundVouleSlider.handlerColor = MY_GREEN_COLOR
        SoundVouleSlider.handlerWidth = 12.0
        SoundVouleSlider.markerCount = 50
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let volume = Float(centralController.sessionSettings.volume) / 100
        SoundVouleSlider.setValue(volume, animated: false)
        
        if silentSettingsChanged == true {
            centralController.silentPeriodDidChange(silentSettings)
            silentSettingsChanged = false
        } else {
            silentSettings = centralController.sessionSettings.silentSettings
        }
        SilentSwitch.isOn = silentSettings!.isDndOn
        SilentFromLabel.text = timeFormatter.string(from: silentSettings!.start! as Date)
        SilentToLabel.text = timeFormatter.string(from: silentSettings!.end! as Date)
    
        if SilentSwitch.isOn == false {
            SilentScheduledLabel.text = "Not scheduled"
        } else {
            SilentScheduledLabel.text = "Scheduled"
        }
    }
    
    // MARK: Outlets -----------------------------------------
    @IBOutlet var networkNameLabel: UILabel!
    @IBOutlet var SoundVouleSlider: DashedSlider!
    @IBOutlet var SilentFromLabel: UILabel!
    @IBOutlet var SilentSwitch: UISwitch!
    @IBOutlet var SilentToLabel: UILabel!    
    @IBOutlet weak var SilentScheduledLabel: UILabel!


    // MARK: Actions -----------------------------------------
    @IBAction func soundValueChanged(_ sender: AnyObject) {
        var value : Float = SoundVouleSlider.value
        value = centralController.soundVoulumeDidChange(value)
    }
    
    // Silent switch did change -------------------------------
    @IBAction func silentSwitchDidChange(_ sender: AnyObject) {
        silentSettings?.isDndOn = SilentSwitch.isOn
        centralController.silentPeriodDidChange(silentSettings)
        if SilentSwitch.isOn == true {
            SilentScheduledLabel.text = "Scheduled"
        } else {
            SilentScheduledLabel.text = "Not scheduled"
        }
        tableView.reloadData()
    }
    
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if (indexPath as NSIndexPath).row == 1 && (indexPath as NSIndexPath).section == 2 {
            if SilentSwitch.isOn == false {
                return 0.0
            } else {
                return 60.0
            }
        }
        return 44.0
    }
    
    
    // MARK: Table view functions
    //-----------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
       
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

// MARK : ToySilentSettingsViewController
// *********************************************************************************************
//-------------------------------------------------------
class ToySilentSettingsViewController: UIViewController {

    // MARK: Properties
    let timeFormatter = DateFormatter()
    var silentSettings = SilentTimeSettings()
    
    // MARK: Functions
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        timeFormatter.timeStyle = DateFormatter.Style.short
    }
    

    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        FromButton.isSelected = true
        silentSettings = centralController.sessionSettings.silentSettings
        TimePicker.date = silentSettings.start! as Date
        var text = "From: " + timeFormatter.string(from: silentSettings.start! as Date)
        FromButton.setTitle(text, for: UIControlState())
        text = "To: " + timeFormatter.string(from: silentSettings.end! as Date)
        ToButton.setTitle(text, for: UIControlState())
    }
    
     // MARK: Outlets
    @IBOutlet var TimePicker: UIDatePicker!
    @IBOutlet var FromButton: UIButton!
    @IBOutlet var ToButton: UIButton!
    
    //MARK: Actions
    //-------------------------------------------------------
    @IBAction func timePickerChanged(_ sender: AnyObject) {
        
        if FromButton.isSelected {
            let text = "From: " + timeFormatter.string(from: TimePicker.date)
            FromButton.setTitle(text, for: UIControlState())
            print(TimePicker.date)
            silentSettings.start! = TimePicker.date
            centralController.toySettingsViewController?.silentSettings!.start = TimePicker.date
        } else {
            let text = "To: " + timeFormatter.string(from: TimePicker.date)
            ToButton.setTitle(text, for: UIControlState())
            silentSettings.end! = TimePicker.date
            centralController.toySettingsViewController?.silentSettings!.end = TimePicker.date
        }
        centralController.toySettingsViewController?.silentSettingsChanged = true
    }

    //-------------------------------------------------------
    @IBAction func fromButtonPressed(_ sender: AnyObject) {
        FromButton.isSelected = true
        ToButton.isSelected = false
        TimePicker.date = silentSettings.start! as Date
    }
    
    //-------------------------------------------------------
    @IBAction func toButtonPressed(_ sender: AnyObject) {
        FromButton.isSelected = false
        ToButton.isSelected = true
        TimePicker.date = silentSettings.end! as Date
    }
}


//-----------------------------------------------------------------------------
//-------------------------------------------------------
class GeneralSettingsTableViewController: UITableViewController, UITextFieldDelegate{
    
    // MARK: Properties

    
    // MARK: Functions
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.hideKeyboardWhenTappedAround()
        ToyNameTextField.delegate = self
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ToyNameTextField.text = centralController.sessionSettings.toyProfile.toyName
        ToyVoiceSegmentCtrl.selectedSegmentIndex = Int(centralController.sessionSettings.voiceType)
    }
    
    @IBOutlet var ToyNameTextField: UITextField!
    @IBOutlet weak var ToyVoiceSegmentCtrl: UISegmentedControl!
    
    //-------------------------------------------------------
    @IBAction func toyVoiceDidChange(_ sender: AnyObject) {
        let newSegmentIndex = ToyVoiceSegmentCtrl.selectedSegmentIndex
        if centralController.voiceTypeDidChange(UInt8(newSegmentIndex)) == false {
            if newSegmentIndex == 0 {
                ToyVoiceSegmentCtrl.selectedSegmentIndex = 1
            } else {
                ToyVoiceSegmentCtrl.selectedSegmentIndex = 0
            }
        }
    }
     
     // Toy Name did change ------------------------------------
     @IBAction func toyNameDidChange(_ sender: AnyObject) {
        if ToyNameTextField.text?.isEmpty == true {
            ToyNameTextField.text? = "KiQ " + String(centralController.sessionSettings.toyProfile.toyID)
        }
        centralController.toyNameDidChange(ToyNameTextField.text!)
     }
    
    
    //-------------------------------------------------------
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        if string == "\n" {
            if ToyNameTextField.text?.isEmpty == true {
                ToyNameTextField.text? = "KiQ " + String(centralController.sessionSettings.toyProfile.toyID)
            }
            centralController.toyNameDidChange(ToyNameTextField.text!)
            textField.resignFirstResponder()
        }
        let maxLength = 20
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
    
    //-----------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
         if (indexPath as NSIndexPath).section == 4 && (indexPath as NSIndexPath).row == 0 {
             if centralController.cloundService.isCloudSessionEnabled() == true {
                displayMyConfirmationMessage("All toy settings will be reset to their defaults and the toy will become available for another user.")
             } else {
                displayNoInternetMessage("Unable to reset Toy. You must be connected to Internet")
             }
         }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //----------------------------------------------------
    func displayNoInternetMessage(_ userMessage:String)
    {
        let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
        let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default){ action -> Void in
        }
        myAlert.addAction(okAction)
        self.present(myAlert , animated: true, completion: nil)
    }
    
    //----------------------------------------------------
    func displayMyConfirmationMessage(_ userMessage:String)
    {
        let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
        let okAction = UIAlertAction(title: "Reset", style: UIAlertActionStyle.default){ action -> Void in
            centralController.toyStatus = ToyStatus.resetting
        }
        myAlert.addAction(okAction);
        let cancelAction = UIAlertAction(title: "Cancel", style: UIAlertActionStyle.default, handler: nil);
        myAlert.addAction(cancelAction);
        self.present(myAlert , animated: true, completion: nil)
    }
}


//-----------------------------------------------------------------------------
//-------------------------------------------------------
class UpgradeToyTableViewController: UITableViewController{
    
    // MARK: Properties
    //var updateRequired : Bool = true
    var updateRequired : Bool = false
    
    // MARK: Functions
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        centralController.updateToyViewController = self
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        InstallNowCell.isHidden = false
        ToyModelLabel.text = "Model: " + String(centralController.sessionSettings.toyProfile.deviceInfo.model)
        ToyRevisionLabel.text = "Revision: " + String(centralController.sessionSettings.toyProfile.deviceInfo.revision)
        ESPrevisionLabel.text = "ESP: " + String(centralController.sessionSettings.toyProfile.deviceInfo.ESPversion)
        NRFrevisionLabel.text = "NRF: " + String(centralController.sessionSettings.toyProfile.deviceInfo.NRFversion)
        PackLabel.text = "SW Pack: " + String(centralController.sessionSettings.toyProfile.deviceInfo.packVersion)
    }
    
    //-------------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        centralController.cloundService.getUpdateInfo() { (success, isUpdateReqyured) in
            if success == true {
                if isUpdateReqyured == false {
                    self.UpdateStatusLabel.text = "Your toy's software is up to date."
                } else {
                    self.updateRequired = isUpdateReqyured
                    self.UpdateStatusLabel.text = "New version of software is available"
                    self.tableView.reloadData()
                }
            } else {
                self.UpdateStatusLabel.text = "Sorry, KiQ Cloud seems to be busy."
            }
            self.UpdateActivityIndicator.stopAnimating()
        }
    }

    @IBOutlet weak var InstallNowCell: UITableViewCell!
    @IBOutlet weak var ToyModelLabel: UILabel!
    @IBOutlet weak var ToyRevisionLabel: UILabel!
    @IBOutlet weak var ESPrevisionLabel: UILabel!
    @IBOutlet weak var NRFrevisionLabel: UILabel!
    @IBOutlet weak var PackLabel: UILabel!
    @IBOutlet weak var UpdateStatusLabel: UILabel!
    @IBOutlet weak var UpdateActivityIndicator: UIActivityIndicatorView!
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if (indexPath as NSIndexPath).section == 1 && (indexPath as NSIndexPath).row == 0 {
            updateToyFirware()
        }
    }
    
    //-------------------------------------------------------
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 1 {
            if updateRequired == false {
                return 0.0
            } else {
                return 44.0
            }
        }
        if indexPath.section == 0  {
            if indexPath.row == 0 {
                return 130.0
            } else {
                return 44.0
            }
        }
        return 44.0
    }
    
    //-------------------------------------------------------
    func updateToyFirware(){
        if centralController.isCharging() == true || centralController.batteryLevel() > 50 {
            centralController.updateToyFirmware()
        } else {
            displayMyAlertMessage("KiQ battery level is too low. Please connect charger and try again.")
        }
    }
    
    //----------------------------------------------------
    func theToyIsBeingUpgraded() {
        _ = self.navigationController?.popToRootViewController(animated: true)
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
    
    
    //----------------------------------------------------
    func isModal() -> Bool {
        if self.presentingViewController != nil {
            return true
        }
        
        if self.presentingViewController?.presentedViewController == self {
            return true
        }
        
        if self.navigationController?.presentingViewController?.presentedViewController == self.navigationController  {
            return true
        }
        
        if self.tabBarController?.presentingViewController is UITabBarController {
            return true
        }
        
        return false
    }
}



