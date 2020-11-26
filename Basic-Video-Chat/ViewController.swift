//
//  ViewController.swift
//  Hello-World
//
//  Created by Roberto Perez Cubero on 11/08/16.
//  Copyright © 2016 tokbox. All rights reserved.
//

import UIKit
import OpenTok

// *** Fill the following variables using your own Project info  ***
// ***            https://tokbox.com/account/#/                  ***
// Replace with your OpenTok API key
let kApiKey = "46492732"
// Replace with your generated session ID
let kSessionId = "2_MX40NjQ5MjczMn5-MTYwNjIxMzU2MTI0Nn5jZ3ZvWTBIOEpMa1ZuQnVjS2Z4eUpMR0t-fg"
// Replace with your generated token
let kToken = "T1==cGFydG5lcl9pZD00NjQ5MjczMiZzaWc9NTU1MTk0Zjg4MWMzMDI5NGU1NGM1NTFiMzMzMTBiNTQzMWZkYWJlMzpzZXNzaW9uX2lkPTJfTVg0ME5qUTVNamN6TW41LU1UWXdOakl4TXpVMk1USTBObjVqWjNadldUQklPRXBNYTFadVFuVmpTMlo0ZVVwTVIwdC1mZyZjcmVhdGVfdGltZT0xNjA2MjEzNTczJm5vbmNlPTAuMzQ4MTAwMzAwNjgyMjMzODUmcm9sZT1wdWJsaXNoZXImZXhwaXJlX3RpbWU9MTYwODgwNTUyNiZpbml0aWFsX2xheW91dF9jbGFzc19saXN0PQ=="

let kWidgetRatio: CGFloat = 1.5

class ViewController: UIViewController {
    
    @IBOutlet weak var remoteView: UIView!
    @IBOutlet weak var localView: UIView!
    
    var changeLocalView = false
    
    lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        let publisher = OTPublisher(delegate: self, settings: settings)!
        publisher.videoCapture = CustomVideoCapture()
        return publisher
    }()
    var enableFilter = true
    var subscriber: OTSubscriber?
    
    func initAudioDevice(_ hasVideo: Bool) {
        var audioDevice = OTDefaultAudioDevice()
//        audioDevice?.hasVideo = hasVideo
        OTAudioDeviceManager.setAudioDevice(audioDevice)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(changeLocalViewToRemote))
        localView.addGestureRecognizer(tapGesture)
        initAudioDevice(true)
        doConnect()
    }
    
    /**
     * Asynchronously begins the session connect process. Some time later, we will
     * expect a delegate method to call us back with the results of this action.
     */
    fileprivate func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.connect(withToken: kToken, error: &error)
    }
    
    /**
     * Sets up an instance of OTPublisher to use with this session. OTPubilsher
     * binds to the device camera and microphone, and will provide A/V streams
     * to the OpenTok session.
     */
    fileprivate func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.publish(publisher, error: &error)
        
        if let pubView = publisher.view {
            
            pubView.frame = localView.bounds
            localView.addSubview(pubView)
        }
    }
    
    /**
     * Instantiates a subscriber for the given stream and asynchronously begins the
     * process to begin receiving A/V content for this stream. Unlike doPublish,
     * this method does not add the subscriber to the view hierarchy. Instead, we
     * add the subscriber only after it has connected and begins receiving data.
     */
    fileprivate func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        
        session.subscribe(subscriber!, error: &error)
    }
    
    fileprivate func cleanupSubscriber() {
        subscriber?.view?.removeFromSuperview()
        subscriber = nil
    }
    
    fileprivate func cleanupPublisher() {
        publisher.view?.removeFromSuperview()
    }
    
    fileprivate func processError(_ error: OTError?) {
        if let err = error {
            DispatchQueue.main.async {
                let controller = UIAlertController(title: "Error", message: err.localizedDescription, preferredStyle: .alert)
                controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
                self.present(controller, animated: true, completion: nil)
            }
        }
    }
    
    @objc func changeLocalViewToRemote() {
        changeLocalView = !changeLocalView
        switchLocalRemoteView(changeLocalView)
    }
    
    @IBAction func didTouchLocalView(_ sender: Any) {
        changeLocalView = !changeLocalView
        switchLocalRemoteView(changeLocalView)
    }
    @objc public func switchLocalRemoteView(_ isZoomLocalVideo: Bool) {
        if isZoomLocalVideo {
            if let publisherView = publisher.view {
                publisherView.removeFromSuperview()
                publisherView.frame = remoteView.bounds
                remoteView.addSubview(publisherView)
            }
            if let subcriberView = subscriber?.view {
                subcriberView.removeFromSuperview()
                subcriberView.frame = localView.bounds
                localView.addSubview(subcriberView)
            }
        } else {
            if let publisherView = publisher.view {
                publisherView.removeFromSuperview()
                publisherView.frame = localView.bounds
                localView.addSubview(publisherView)
            }
            if let subcriberView = subscriber?.view {
                subcriberView.removeFromSuperview()
                subcriberView.frame = remoteView.bounds
                remoteView.addSubview(subcriberView)
            }
        }
    }
    
    
    @IBAction func didTouchSwitchCamera(_ sender: Any) {
        if let capture = publisher.videoCapture as? CustomVideoCapture {
            capture.switchCamera()
        }
    }
    
    @IBAction func didTouchOnOff(_ sender: Any) {
        enableFilter = !enableFilter
        
        if let capture = publisher.videoCapture as? CustomVideoCapture {
            capture.enableFilter(enableFilter)
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        let currentValue = Float(sender.value)
        print("------\(currentValue)")
        if let capture = publisher.videoCapture as? CustomVideoCapture {
            capture.changeBeauty(currentValue)
        }
    }
}

// MARK: - OTSession delegate callbacks
extension ViewController: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        if subscriber == nil {
            doSubscribe(stream)
        }
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
    }
    
}

// MARK: - OTPublisher delegate callbacks
extension ViewController: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriber delegate callbacks
extension ViewController: OTSubscriberDelegate {
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        if let subsView = subscriber?.view {
            subsView.frame = remoteView.bounds
            remoteView.addSubview(subsView)
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
    }
}
