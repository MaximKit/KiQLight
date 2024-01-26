//
//  FeedbackViewController.swift
//  Toy
//
//  Created by Maxim Kitaygora on 10/7/16.
//  Copyright © 2016 Signe Networks. All rights reserved.
//

import Foundation
import UIKit

//------------------------------------
class FeedbackViewController: UIViewController {

    
    //-------------------------------------------------
    override func viewDidLoad() {
        super.viewDidLoad()
        submitButton.layer.borderWidth = 0.5
        submitButton.layer.cornerRadius = 5.0
        submitButton.layer.borderColor = MY_RED_COLOR.cgColor
        
        switch UIScreen.main.bounds.height {
            
        case 480:  //iPhone 4S
            break
        case 568:  //iPhone 5S
            
            break
        default:
            submitButtonYConstraint.constant = 30
            break
        }

        
    }

    //-------------------------------------------------
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        feedbackTextView.becomeFirstResponder()
    }
    
    
    @IBOutlet weak var feedbackTextView: UITextView!
    @IBOutlet weak var submitButton: UIButton!
    @IBOutlet weak var submitButtonYConstraint: NSLayoutConstraint!
    
    
    //-------------------------------------------------
    @IBAction func submitButtonTapped(_ sender: AnyObject) {
        feedbackTextView.resignFirstResponder()
        
        let alertController = UIAlertController(title: nil, message: "Sending..\n\n", preferredStyle: UIAlertControllerStyle.alert)
        let spinnerIndicator: UIActivityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
        spinnerIndicator.center = CGPoint(x: 135.0, y: 65.5)
        spinnerIndicator.color = UIColor.black
        spinnerIndicator.startAnimating()
        
        alertController.view.addSubview(spinnerIndicator)
        self.present(alertController, animated: false, completion: nil)
        centralController.cloundService.sendFeedback(feedbackTextView.text, completion: { (success) in
            alertController.dismiss(animated: true, completion: nil)
            if success == true {
                let viewControllers: [UIViewController] = self.navigationController!.viewControllers as [UIViewController];
                self.navigationController!.popToViewController(viewControllers[viewControllers.count - 2], animated: true);
            } else {
                self.displayMyAlertMessage ("KiQ Cloud is not accessible. Please try again leter.")
            }
        })
    }
    
    //----------------------------------------------------
    func displayMyAlertMessage(_ userMessage:String)
    {
        if isModal() == true {
            let myAlert = UIAlertController(title: "Alert", message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
            let okAction = UIAlertAction(title: "Ok", style: UIAlertActionStyle.default) { action -> Void in
                self.feedbackTextView.becomeFirstResponder()
            }
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
