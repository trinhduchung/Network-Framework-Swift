//
//  ViewController.swift
//  ClientApp
//
//  Created by Duc Hung Trinh on 13/7/18.
//  Copyright © 2018 Hung. All rights reserved.
//

import UIKit
import Network

class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    private let myQueue = DispatchQueue(label: "my_queue")
    
    private var connection: NWConnection!
    
    private var streamReader: StreamReader!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.borderColor = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        textView.layer.borderWidth = 1
        
        if let path = Bundle.main.path(forResource: "data", ofType: "txt") {
            streamReader = StreamReader(url: URL(string: path)!)
        }
        
        let nwPathMonitoring = NWPathMonitor()
        nwPathMonitoring.start(queue: myQueue)
        nwPathMonitoring.pathUpdateHandler = { path in
            self.updateTextView("[PathUpdateHandler] path \(path)")
        }
        
        // Name by default is machine's name and domain is local
        let endPoint = NWEndpoint.service(name: "Hung", type: "_demo._tcp", domain: "local", interface: nil)
        let nwParams = NWParameters(tls: nil, tcp:NWProtocolTCP.Options())
        nwParams.serviceClass = .background
        nwParams.allowFastOpen = true
        connection =  NWConnection(to: endPoint, using: nwParams)
        
        connection.stateUpdateHandler = { newState in
            switch newState {
            case .ready:
                self.updateTextView("[StateUpdateHandler] ready")
                break
            case .waiting(let error):
                self.updateTextView("[StateUpdateHandler] waiting - \(error.localizedDescription)")
                break
            case .failed(let error):
                self.updateTextView("[StateUpdateHandler] failed - \(error.localizedDescription)")
                break
            default:
                break
            }
        }
        
        connection.viabilityUpdateHandler = { isViable in
            if (!isViable) {
                self.updateTextView("[ViabilityUpdateHandler] Handle connection temporarily losing connectivity")
            } else {
                self.updateTextView("[ViabilityUpdateHandler] Handle connection return to connectivity")
            }
        }
        
        connection.betterPathUpdateHandler = { betterPathAvailable in
            if (betterPathAvailable) {
                self.updateTextView("[BetterPathUpdateHandler] Start a new connection if migration is possible")
            } else {
                self.updateTextView("[BetterPathUpdateHandler] Stop any attempts to migrate")
            }
        }
    }
    
    private func updateTextView(_ text: String) {
        DispatchQueue.main.async {
            self.textView.text = self.textView.text + "\n\(text)"
        }
    }

    @IBAction func didConnectButtonPress(_ sender: Any) {
        connection.start(queue: myQueue)
    }
    
    @IBAction func didSendButtonPress(_ sender: Any) {
//        sendLoop(connection)
        if let nextLine = streamReader.nextLine(), nextLine.count > 0 {
            connection.send(content: nextLine.data(using: .utf8), completion: NWConnection.SendCompletion.contentProcessed({ (error) in
            }))
        }
    }
    
    private func sendLoop(_ connection: NWConnection) {
        if streamReader.isEOF() {
            connection.cancel()
            return
        }
        
        if let nextLine = streamReader.nextLine(), nextLine.count > 0 {
            print("Read line \(nextLine)")
            connection.send(content: nextLine.data(using: .utf8), completion: NWConnection.SendCompletion.contentProcessed({ (error) in
                if let _ = error {
                    connection.cancel()
                } else {
                    self.sendLoop(connection)
                }
            }))
        } else {
            sendLoop(connection)
        }
    }
}

