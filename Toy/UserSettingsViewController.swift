//
//  UserSettingsViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 2/2/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit

//-------------------------------------------------------
class UserSettingsTableViewController: UITableViewController, UITextFieldDelegate{
    
    // MARK: Properties
    
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        centralController.userSettingsViewController = self
        UserNameTextField.delegate = self
        UserNameTextField.tag = 1
        EmailTextField.delegate = self
        EmailTextField.tag = 2
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UserNameTextField.text = centralController.sessionSettings.userProfile.name
        EmailTextField.text = centralController.sessionSettings.userProfile.email
        
        if centralController.sessionSettings.userProfile.phone.isEmpty != true {
            PhoneNumberLabel.text = centralController.sessionSettings.userProfile.phone
        } else {
            PhoneNumberLabel.text = "Add Your Phone Number"
        }
    }
    
    @IBOutlet weak var UserNameTextField: UITextField!
    @IBOutlet weak var EmailTextField: UITextField!
    @IBOutlet weak var PhoneNumberLabel: UILabel!

    
    //-------------------------------------------------------
    //-----------------------------------
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (indexPath as NSIndexPath).section == 3 && (indexPath as NSIndexPath).row == 0 {
            
            _ = self.navigationController?.popViewController(animated: true)
            centralController.logout() {(success) -> Void in
                if success != true {
                    self.displayMyAlertMessage("Unable to logout due to some KiQ Cloud problems. Please try again later")
                }
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    //-------------------------------------------------------
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        var maxLength = 0
        switch textField.tag {
        case 1:
            if string == "\n" {
                if UserNameTextField.text != nil {
                    if centralController.sessionSettings.userProfile.name != UserNameTextField.text {
                        centralController.sessionSettings.userProfile.name = UserNameTextField.text!
                        centralController.cloundService.updateUser(centralController.sessionSettings, completion: nil)
                    }
                }
                textField.resignFirstResponder()
            }
            maxLength = 50
            break
            
        case 2:
            if string == "\n" {
                if EmailTextField.text != nil {
                    if centralController.sessionSettings.userProfile.email != EmailTextField.text {
                        centralController.sessionSettings.userProfile.email = EmailTextField.text!
                        centralController.cloundService.updateUser(centralController.sessionSettings, completion: nil)
                    }
                }
                textField.resignFirstResponder()
            }
            maxLength = 50
            break
        default:
            break
        }
        let currentString: NSString = textField.text! as NSString
        let newString: NSString = currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
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

//------------------------------------------------------------------------------------
class UserProfilePhoneVerificationController: UIViewController, UITextFieldDelegate{
    
    // MARK: Properties
    //----------------------------------------------------
    var getVerificationCodeTimer: Timer?
    var clearPhoneMessageTimer: Timer?
    var clearCodeMessageTimer: Timer?
    var requestCodeSecRemaining: Int = 0
    
    //-------------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        phoneNumberTextField.delegate = self
        phoneNumberTextField.tag = 1
        verificationCodeTextField.delegate = self
        verificationCodeTextField.tag = 2
        requestButton.layer.borderWidth = 0.5
        requestButton.layer.cornerRadius = 5.0
        requestButton.layer.borderColor = MY_RED_COLOR.cgColor
        requestButton.layer.backgroundColor = MY_RED_COLOR.cgColor
    }
    
    //-------------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        phoneNumberTextField.text = centralController.sessionSettings.userProfile.phone
        verificationCodeTextField.isHidden = true
        verificationHintLabel.isHidden = true
        phoneActivityIndicator.stopAnimating()
        codeActivityIndicator.stopAnimating()
        requestButton.layer.borderColor = MY_RED_COLOR.cgColor
        requestButton.layer.backgroundColor = MY_RED_COLOR.cgColor
        requestButton.setTitle("Request Verification Code", for: UIControlState.normal)
        phoneNumberTextField.becomeFirstResponder()
    }
    
    //-------------------------------------------------------
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        clearPhoneMessageTimer?.invalidate()
        clearCodeMessageTimer?.invalidate()
        phoneActivityIndicator.stopAnimating()
        codeActivityIndicator.stopAnimating()
    }
    
    @IBOutlet weak var phoneNumberTextField: UITextField!
    @IBOutlet weak var phoneHintLabel: UILabel!
    @IBOutlet weak var verificationCodeTextField: UITextField!
    @IBOutlet weak var verificationHintLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var codeActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var phoneActivityIndicator: UIActivityIndicatorView!
    
    //-------------------------------------------------------
    @IBAction func requestButtonTapped(_ sender: AnyObject) {
        if requestButton.title(for: UIControlState.normal) == "Request Verification Code" {
            // Check for empty fields
            if phoneNumberTextField.text!.isEmpty
            {
                // Display alert message
                displayPhoneHintMessage("Phone number field cannot be empty");
                return;
            }
            self.view.endEditing(true)
            phoneHintLabel.isHidden = true
            phoneActivityIndicator.startAnimating()
            
            centralController.cloundService.startPhoneLogin(phoneNumberTextField.text!){ (success, response) -> Void in
                DispatchQueue.main.async{
                    self.phoneActivityIndicator.stopAnimating()
                    if success != true {
                        #if DEBUG
                            print ("DBG: processPhoneNumber error = ", response ?? "Unknown error")
                        #endif
                        if response == ""{
                            self.displayPhoneHintMessage ("Server unavailable.")
                        }
                        else {
                            self.displayPhoneHintMessage ("Incorrect phone number")
                        }
                    } else {
                        self.requestButton.layer.borderColor = MY_GREEN_COLOR.cgColor
                        self.requestButton.layer.backgroundColor = MY_GREEN_COLOR.cgColor
                        self.requestButton.setTitle("Confirm Verification Code", for: UIControlState.normal)
                        self.phoneNumberTextField.isEnabled = false
                        self.verificationCodeTextField.isHidden = false
                        self.verificationHintLabel.isHidden = false
                        self.verificationCodeTextField.becomeFirstResponder()
                    }
                }
            }
        } else {
            guard verificationCodeTextField.text!.isEmpty == false
                else {
                    displayCodeHintMessage("Verification code field cannot be empty")
                    return;
            }
            
            if self.codeActivityIndicator.isAnimating == false{
                verificationHintLabel.isHidden = true
                self.codeActivityIndicator.startAnimating()
                centralController.cloundService.processSMSCode(verificationCodeTextField.text!){ (success) -> Void in
                    self.codeActivityIndicator.stopAnimating()
                    if success != true {
                        self.displayCodeHintMessage("Verification code is incorrect")
                        self.verificationCodeTextField.text = ""
                    } else {
                        centralController.sessionSettings.userProfile.phone = self.phoneNumberTextField.text!
                        _ = self.navigationController?.popToViewController(centralController.userSettingsViewController!, animated: true)
                    }
                }
            }
        }
    }

    
    //----------------------------------------------------
    func displayPhoneHintMessage(_ userMessage:String)
    {
        phoneHintLabel.isHidden = false
        phoneHintLabel.textColor = MY_RED_COLOR
        phoneHintLabel.text = userMessage
        if clearPhoneMessageTimer != nil{
            clearPhoneMessageTimer?.invalidate()
        }
        clearPhoneMessageTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(clearPhoneHintMessage), userInfo: nil, repeats: false)
    }
    
    //----------------------------------------------------
    @objc func clearPhoneHintMessage() {
        phoneHintLabel.textColor = UIColor.black
        phoneHintLabel.text = "Please provide a valid phone number"
        clearPhoneMessageTimer?.invalidate()
        clearPhoneMessageTimer = nil
        phoneNumberTextField.becomeFirstResponder()
    }

    //----------------------------------------------------
    func displayCodeHintMessage(_ userMessage:String)
    {
        verificationHintLabel.isHidden = false
        verificationHintLabel.textColor = MY_RED_COLOR
        verificationHintLabel.text = userMessage
        if clearCodeMessageTimer != nil{
            clearCodeMessageTimer?.invalidate()
        }
        clearPhoneMessageTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(clearCodeHintMessage), userInfo: nil, repeats: false)
    }
    
    //----------------------------------------------------
    @objc func clearCodeHintMessage() {
        verificationHintLabel.textColor = UIColor.black
        verificationHintLabel.text = "Enter received verification code"
        clearCodeMessageTimer?.invalidate()
        clearCodeMessageTimer = nil
    }
    
    //-------------------------------------------------------
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool
    {
        var maxLength = 0
        switch textField.tag {
        case 1:
            if string == "\n" {
                if phoneNumberTextField.text != nil {

                }
                textField.resignFirstResponder()
            }
            
            maxLength = 12
            break
            
        case 2:
            if string == "\n" {
                guard verificationCodeTextField.text!.isEmpty == false
                    else {
                        displayCodeHintMessage("Verification code field cannot be empty")
                        return true;
                }
                textField.resignFirstResponder()
                
            }
            maxLength = 10
            break
        default:
            break
        }
        let currentString: NSString = textField.text! as NSString
        let newString: NSString =
            currentString.replacingCharacters(in: range, with: string) as NSString
        return newString.length <= maxLength
    }
}
