//
//  LoginViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 1/28/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit
import FBSDKCoreKit
import FBSDKShareKit
import FBSDKLoginKit


//---------------------------------------------
//MARK: UIViewController extension
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

//---------------------------------------------
//MARK: Login Screen
//---------------------------------------------
class LoginViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: Properties
    //----------------------------------------------------
    var isLoginFinished : Bool = false
    var clearCloudMessageTimer: Timer?
    var clearFacebookMessageTimer: Timer?
    
    //MARK: Initialization
    //----------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        self.hideKeyboardWhenTappedAround()
        UserPhoneNumber.delegate = self
        UserPhoneNumber.layer.borderColor = UIColor.lightGray.cgColor
        UserPhoneNumber.layer.borderWidth = 0.5
        UserPhoneNumber.layer.cornerRadius = 5.0
        LoginButton.layer.borderWidth = 0.5
        LoginButton.layer.cornerRadius = 5.0
        LoginButton.layer.borderColor = MY_RED_COLOR.cgColor
        LoginButton.layer.backgroundColor = MY_RED_COLOR.cgColor
        centralController.loginViewController = self
    }
    
    //----------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async{
            self.CloudMessageLabel.isHidden = true
            self.CloudMessageLabel.text = "1"
            self.ActivityIndicator.stopAnimating()
            self.FacebookFailedLabel.isHidden = true
            self.FacebookActivityIndicator.stopAnimating()
        }
    }
    
    
    //----------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if self.isLoginFinished {
            self.dismiss(animated: true, completion: nil)
            self.isLoginFinished = false
        }
    }
    // MARK: Outlets
    //----------------------------------------------------

    @IBOutlet var UserPhoneNumber: UITextField!
    @IBOutlet var LoginButton: UIButton!
    @IBOutlet var ServiceTermsButton: UIButton!
    @IBOutlet var CloudMessageLabel: UILabel!
    @IBOutlet var ActivityIndicator: UIActivityIndicatorView!
    @IBOutlet var FacebookLoginButton: UIButton!
    @IBOutlet var FacebookFailedLabel: UILabel!
    @IBOutlet var FacebookActivityIndicator: UIActivityIndicatorView!
    
    // MARK: Functions
    //----------------------------------------------------
    @IBAction func loginButtonPressed(_ sender: AnyObject) {
        
        // Check for empty fields
        if UserPhoneNumber.text!.isEmpty
        {
            // Display alert message
            displayPhoneHintMessage("Phone number field cannot be empty");
            CloudMessageLabel.isHidden = false
            return;
        }
        
        if centralController.internetConnectionStatus == InternetConnectionStatus.notConnected {
            // Display alert message
            displayPhoneHintMessage("Internet connection is required");
            CloudMessageLabel.isHidden = false
            return;
        }
        
        if self.ActivityIndicator.isAnimating == false{
            ActivityIndicator.startAnimating()
            self.view.endEditing(true)
            CloudMessageLabel.isHidden = true
            centralController.cloundService.startPhoneLogin(UserPhoneNumber.text!){ (success, response) -> Void in
                DispatchQueue.main.async{
                    self.ActivityIndicator.stopAnimating()
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
                        let verificationController = self.storyboard?.instantiateViewController(withIdentifier: "VerificationViewController") as? VerificationViewController
                        verificationController?.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
                        self.present(verificationController!, animated:true, completion: nil)
                    }
                }
            }
        }
    }
    
    //----------------------------------------------------
    @IBAction func privacyButtonTapped(_ sender: AnyObject) {
        if let url = URL(string: "https://kiqtoy.com/privacy-policy") {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(url)
            }
        }

    }
    
    //----------------------------------------------------
    func displayPhoneHintMessage(_ userMessage:String)
    {
        CloudMessageLabel.isHidden = false
        CloudMessageLabel.text = userMessage
        if clearCloudMessageTimer != nil{
            clearCloudMessageTimer?.invalidate()
        }
        clearCloudMessageTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(clearPhoneHintdMessage), userInfo: nil, repeats: true)
    }

    //----------------------------------------------------
    @objc func clearPhoneHintdMessage() {
        CloudMessageLabel.isHidden = true
        CloudMessageLabel.text = "1"
        clearCloudMessageTimer?.invalidate()
        clearCloudMessageTimer = nil
    }
    
    //----------------------------------------------------
    @IBAction func loginFacebookAction(_ sender: AnyObject) {
        if centralController.internetConnectionStatus == InternetConnectionStatus.cellularConnected || centralController.internetConnectionStatus == InternetConnectionStatus.wiFiConnected{
            let fbLoginManager : FBSDKLoginManager = FBSDKLoginManager()
            
            fbLoginManager.logIn(withReadPermissions: ["public_profile", "email", "user_friends"], from: self) { (result, error) -> Void in
                if (error == nil){
                    let fbloginresult : FBSDKLoginManagerLoginResult = result!
                    if(fbloginresult.grantedPermissions.contains("email") && fbloginresult.grantedPermissions.contains("public_profile"))
                    {
                        self.UserPhoneNumber.isEnabled = false
                        self.LoginButton.isEnabled = false
                        self.FacebookLoginButton.isEnabled = false
                        self.getFBUserData()
                    }
                }
            }
        } else {
            self.displayFacebookMessage("Internet connection appears to be off.")
        }
    }
    
    //----------------------------------------------------
    func getFBUserData(){
        if((FBSDKAccessToken.current()) != nil){
            let graphRequest : FBSDKGraphRequest = FBSDKGraphRequest(graphPath: "me", parameters: ["fields": " id, name, email"])
            graphRequest.start(completionHandler: { (connection, result, error) -> Void in
                DispatchQueue.main.async{
                    self.FacebookActivityIndicator.stopAnimating()
                }
                if ((error) != nil)
                {
                    #if DEBUG
                        print ("ERROR: loggin to Facebook failed")
                    #endif
                    self.displayFacebookMessage("Login with Facebook failed.")
                    self.logoutFromFacebook()
                    self.UserPhoneNumber.isEnabled = true
                    self.LoginButton.isEnabled = true
                    self.FacebookLoginButton.isEnabled = true
                }
                else
                {
                    //guard let userID: String = (result as AnyObject).value(forKey: "id") as? String
                    guard let userID: String = (result as! NSDictionary).value(forKey: "id") as? String
                        else {
                            #if DEBUG
                                print ("ERROR: get Facebook UserID failed")
                            #endif
                            self.displayFacebookMessage("Oops... Login with Facebook failed")
                            self.logoutFromFacebook()
                            self.UserPhoneNumber.isEnabled = true
                            self.LoginButton.isEnabled = true
                            self.FacebookLoginButton.isEnabled = true
                            return
                    }
                    var name : String = ""
                    if let str: String = (result as! NSDictionary).value(forKey: "name") as? String{
                        name = str
                    }
                    var email : String = ""
                    if let str : String = (result as! NSDictionary).value(forKey: "email") as? String {
                        email = str
                    }
                    centralController.cloundService.processFacebookLogin(userID, name: name, email: email, completion: { (success) in
                        DispatchQueue.main.async{
                            if success != true {
                                self.UserPhoneNumber.isEnabled = true
                                self.LoginButton.isEnabled = true
                                self.FacebookLoginButton.isEnabled = true
                                self.displayFacebookMessage("Oops... Login with Facebook failed")
                                self.logoutFromFacebook()
                            } else {
                                self.UserPhoneNumber.isEnabled = true
                                self.LoginButton.isEnabled = true
                                self.FacebookLoginButton.isEnabled = true
                                self.dismiss(animated: true, completion: { () -> Void in
                                    centralController.startBLEConnection(centralController.cloundService.getCloudBaseInfo())
                                })
                            }
                        }
                    })
                }
            })
            
        }
    }
    
        
    //----------------------------------------------------
    func loginButtonDidLogOut(_ loginButton: FBSDKLoginButton!){
        logoutFromFacebook()
    }
    
    //----------------------------------------------------
    func logoutFromFacebook(){
        let loginManager: FBSDKLoginManager = FBSDKLoginManager()
        loginManager.logOut()
    }
    
    //----------------------------------------------------
    func displayFacebookMessage(_ message: String)
    {
        FacebookFailedLabel.text = message
        FacebookFailedLabel.isHidden = false
        if clearFacebookMessageTimer != nil{
            clearFacebookMessageTimer?.invalidate()
        }
        clearFacebookMessageTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(clearFacebookMessage), userInfo: nil, repeats: true)
    }
    
    //----------------------------------------------------
    @objc func clearFacebookMessage() {
        FacebookFailedLabel.isHidden = true
        clearFacebookMessageTimer?.invalidate()
    }
}


//---------------------------------------------
class VerificationViewController: UIViewController, UITextFieldDelegate {
    
    // MARK: Properties
    //----------------------------------------------------
    var getVerificationCodeTimer: Timer?
    var clearCloudMessageTimer: Timer?
    var requestCodeSecRemaining: Int = 0
    
    //MARK: Initialization
    //----------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        okButton.layer.borderWidth = 0.5
        okButton.layer.cornerRadius = 5.0
        okButton.layer.borderColor = MY_RED_COLOR.cgColor
        okButton.layer.backgroundColor = MY_RED_COLOR.cgColor
        centralController.verificationViewController = self
        let screenSize: CGRect = UIScreen.main.bounds
        switch screenSize.height {
        case 480: //4S
            YouCanRequestConstraint.constant = 12
            VerifTextConstraint.constant = 8
            RequestBtnConstraint.constant = 8
            TopOffsetConstraint.constant = 40
            TopOffsetConstraint.constant = 10
            YouCanRequestLabel.setFontSize(15)
            RequestCodeBtn.titleLabel?.setFontSize(15)
            TopMessageLabel.setFontSize(15)
            break
            
        case 568:  //iPhone 5S
            TopOffsetConstraint.constant = 30
            YouCanRequestLabel.setFontSize(15)
            RequestCodeBtn.titleLabel?.setFontSize(15)
            TopMessageLabel.setFontSize(15)
            break
            
        case 667: //6, 6S
            TopOffsetConstraint.constant = 100
            break
            
        case 736:  //6Plus
            TopOffsetConstraint.constant = 120
            break
            
        default:
            break
        }
    }
    
    //----------------------------------------------------
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.CloudMessageLabel.isHidden = true
        self.ActivityIndicator.stopAnimating()
        VerificationTextField.becomeFirstResponder()
        requestCodeSecRemaining = 30
        YouCanRequestLabel.text = "You can request code again in 30 sec"
        YouCanRequestLabel.isHidden = false
        RequestCodeBtn.isEnabled = false
        RequestCodeBtn.isHidden = true
        getVerificationCodeTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(enableResendButton), userInfo: nil, repeats: true)
    }
    
    //----------------------------------------------------
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        getVerificationCodeTimer?.invalidate()
        clearCloudMessageTimer?.invalidate()
    }
    
    //----------------------------------------------------
    @IBOutlet var okButton: UIButton!
    @IBOutlet var VerificationTextField: UITextField!
    @IBOutlet var RequestCodeBtn: UIButton!
    @IBOutlet var ActivityIndicator: UIActivityIndicatorView!
    @IBOutlet var CloudMessageLabel: UILabel!
    @IBOutlet var YouCanRequestLabel: UILabel!
    @IBOutlet var TopOffsetConstraint: NSLayoutConstraint!
    @IBOutlet var TopMessageLabel: UILabel!
    @IBOutlet var VerifTextConstraint: NSLayoutConstraint!
    @IBOutlet var RequestBtnConstraint: NSLayoutConstraint!
    @IBOutlet var SendBtnConstraint: NSLayoutConstraint!
    @IBOutlet var YouCanRequestConstraint: NSLayoutConstraint!
    
   //----------------------------------------------------
    @IBAction func okButtonTapped(_ sender: AnyObject) {
        guard VerificationTextField.text!.isEmpty == false
            else {
                displayCloudMessage("Verification code field cannot be empty")
                return;
            }
        
        if centralController.internetConnectionStatus == InternetConnectionStatus.notConnected {
            // Display alert message
            displayCloudMessage("Internet connection is required");
            return;
        }
        
        if self.ActivityIndicator.isAnimating == false{
            CloudMessageLabel.isHidden = true
            self.ActivityIndicator.startAnimating()
            centralController.cloundService.processSMSCode(VerificationTextField.text!){ (success) -> Void in
                self.ActivityIndicator.stopAnimating()
                if success != true {
                    self.displayCloudMessage("Verification code incorrect")
                    self.VerificationTextField.text = ""
                } else {
                    centralController.loginViewController?.isLoginFinished = true
                    self.dismiss(animated: true, completion: { () -> Void in
                        centralController.startBLEConnection(centralController.cloundService.getCloudBaseInfo())
                    })
                }
            }
        }
    }
    
    //----------------------------------------------------
    @IBAction func requestVerificationCodeTapped(_ sender: AnyObject) {
        requestCodeSecRemaining = 30
        YouCanRequestLabel.text = "You can request a code again in 30 sec"
        YouCanRequestLabel.isHidden = false
        RequestCodeBtn.isEnabled = false
        RequestCodeBtn.isHidden = true
        getVerificationCodeTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(enableResendButton), userInfo: nil, repeats: true)
        
        centralController.cloundService.resendVerificationCode(){ (success) -> Void in
            self.ActivityIndicator.stopAnimating()
            if success != true {
                self.displayCloudMessage("The server is unavailable")
            } else {
                 self.displayCloudMessage("Verification code resent")
            }
        }
    }
    
    //----------------------------------------------------
    @objc func enableResendButton() {
        requestCodeSecRemaining = requestCodeSecRemaining - 1
        if requestCodeSecRemaining != 0 {
            YouCanRequestLabel.text = "You can request a code again in " + String(self.requestCodeSecRemaining) + " sec"
        } else {
            YouCanRequestLabel.isHidden = true
            RequestCodeBtn.isEnabled = true
            RequestCodeBtn.isHidden = false
            getVerificationCodeTimer?.invalidate()
            getVerificationCodeTimer = nil
        }
        
    }
    
    //----------------------------------------------------
    @IBAction func cancelButtonTapped(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //----------------------------------------------------
    func displayCloudMessage(_ userMessage:String)
    {
        CloudMessageLabel.isHidden = false
        CloudMessageLabel.text = userMessage
        if clearCloudMessageTimer != nil{
            clearCloudMessageTimer?.invalidate()
        }
        clearCloudMessageTimer = Timer.scheduledTimer(timeInterval: 3, target: self, selector: #selector(clearCloudMessage), userInfo: nil, repeats: true)
    }
    
    //----------------------------------------------------
    @objc func clearCloudMessage() {
        CloudMessageLabel.text = ""
        clearCloudMessageTimer?.invalidate()
        clearCloudMessageTimer = nil
    }
}
