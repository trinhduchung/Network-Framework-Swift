//
//  ViewController.swift
//  ServerApp
//
//  Created by Duc Hung Trinh on 13/7/18.
//  Copyright © 2018 Hung. All rights reserved.
//

import UIKit
import Network

@available(iOS 12.0, *)
class ViewController: UIViewController {

    @IBOutlet weak var textView: UITextView!
    
    let myQueue = DispatchQueue(label: "my_queue")
    var listener: NWListener!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        textView.layer.borderWidth = 1
        
        let nwPathMonitoring = NWPathMonitor()
        nwPathMonitoring.start(queue: myQueue)
        nwPathMonitoring.pathUpdateHandler = { path in
            self.updateTextView("[PathUpdateHandler] path \(path)")
        }
        
        do {
            listener = try NWListener(parameters: .tcp)
            if let listener = listener {
                listener.service = NWListener.Service(type: "_demo._tcp")
                
                listener.serviceRegistrationUpdateHandler = { state in
                    self.updateTextView("[ServiceRegistrationChange] new state \(state)")
                }
                
                listener.newConnectionHandler = { [weak self] (newConnection) in
                    guard let strongSelf = self else {return}
                    
                    strongSelf.updateTextView("[NewConnectionHandler] new connection \(newConnection)")
                    
                    newConnection.start(queue: strongSelf.myQueue)
                    strongSelf.receiveLoop(newConnection)
                }
                
                listener.stateUpdateHandler = { (newState) in
                    self.updateTextView("[StateUpdateHandler] new state \(newState)")
                }
            }
        } catch let error {
            self.updateTextView("[ListenerError] error \(error)")
        }
    }
    
    /*
     Start an asynchronous read.
     When the read completes, start an asynchronous write.
     When the write completes, set up the next asynchronous read, which starts again at step 1.
     */
    func receiveLoop(_ connection: NWConnection) {
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: Int(INT32_MAX)) { (data, context, isComplete, error) in
            
            let scheduleNextReceive = {
                if let context = context, context.isFinal, isComplete {
                    connection.cancel()
                } else if let error = error {
                    self.updateTextView("[ReceiveData] error \(error)")
                    connection.cancel()
                } else {
                    self.receiveLoop(connection)
                }
            }
            
            if context != nil {
                if let data = data {
                    self.updateTextView("[ReceiveData] \(String(data: data, encoding: .utf8)  ?? "")")
                }
                scheduleNextReceive()
            } else {
                // No content, so directly schedule the next receive
                scheduleNextReceive()
            }
        }
    }
    
    private func updateTextView(_ text: String) {
        DispatchQueue.main.async {
            self.textView.text = self.textView.text + "\n\(text)"
        }
    }
    
    @IBAction func didStartButtonPress(_ sender: Any) {
        listener.start(queue: myQueue)
    }
}

