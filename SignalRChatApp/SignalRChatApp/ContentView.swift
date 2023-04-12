//
//  ContentView.swift
//  SignalRChatApp
//
//  Created by Pawel Kadluczka on 2/25/23.
//

import SwiftUI
import SignalRClient

struct Message: Hashable, Codable {
    let name: String
    let text: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(text)
    }
}

fileprivate class ChatHubDelegate: HubConnectionDelegate {
    var connectionDidOpenFunc: ((HubConnection) -> Void)?
    var connectionDidFailToOpenFunc: ((Error) -> Void)?
    var connectionDidCloseFunc: ((Error?) -> Void)?
    var connectionWillReconnectFunc: ((Error) -> Void)?
    var connectionDidReconnectFunc: (() -> Void?)?

    func connectionDidOpen(hubConnection: SignalRClient.HubConnection) {
        connectionDidOpenFunc?(hubConnection)
    }

    func connectionDidFailToOpen(error: Error) {
        connectionDidFailToOpenFunc?(error)
    }

    func connectionDidClose(error: Error?) {
        connectionDidCloseFunc?(error)
    }

    func connectionWillReconnect(error: Error) {
        connectionWillReconnectFunc?(error)
    }

    func connectionDidReconnect() {
        connectionDidReconnectFunc?()
    }
}

struct ContentView: View {
    enum PopupKind {
        case none
        case name
        case error
        case errorRestart
        case reconnect
    }

    @State private var popupKind: PopupKind = .name
    @State private var errorMessage = ""
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var name = ""
    @State private var streamHandle: StreamHandle? = nil
    private let chatHubConnection: HubConnection
    private let chatHubDelegate = ChatHubDelegate()

    func connectionDidOpen(hubConnection: HubConnection) {
    }

    func connectionDidFailToOpen(error: Error) {
        errorMessage = "\(error.localizedDescription)"
        popupKind = .errorRestart
    }

    func connectionDidClose(error: Error?) {
        if let e = error {
            errorMessage = "\(e.localizedDescription)"
            popupKind = .errorRestart
        }
    }

    func connectionWillReconnect(error: Error) {
        popupKind = .reconnect
    }

    func connectionDidReconnect() {
        popupKind = .none
    }

    init() {
        chatHubConnection = HubConnectionBuilder(url: URL(string: "http://192.168.86.25:5000/chat")!)
            .withHubConnectionDelegate(delegate: chatHubDelegate)
            .withAutoReconnect()
            .build()
    }

    var body: some View {
        VStack {
            List(messages, id: \.self) {
                Text("**\($0.name)**: \($0.text)")
            }

            HStack {
                TextField("Type a message", text: $newMessage)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(action: {
                    if newMessage == "/dadjoke" {
                        chatHubConnection.invoke(method: "DadJoke", resultType: String.self) {
                            joke, error in
                            if let e = error {
                                errorMessage = "\(e)"
                                popupKind = .error
                            } else {
                                messages.append(Message(name: "Dad", text: joke ?? "Dad is tired today"))
                                newMessage = ""
                            }
                            return
                        }
                    }
                    if newMessage == "/count" {
                        guard streamHandle == nil else {
                            return
                        }

                        streamHandle = chatHubConnection.stream(method: "CountDown", 5, streamItemReceived: {(n:Int) in self.messages.append(Message(name: "Counter", text: "\(n)"))}, invocationDidComplete: { error in
                            self.messages.append(Message(name: "Counter", text: "Counting finished"))
                            streamHandle = nil
                        })
                        newMessage = ""
                        return
                    }
                    if newMessage == "/cancel" {
                        guard streamHandle != nil else {
                            return
                        }
                        chatHubConnection.cancelStreamInvocation(streamHandle: streamHandle!) {_ in }
                        newMessage = ""
                        return
                    }
                    chatHubConnection.send(method: "Broadcast", Message(name: name, text: newMessage)) {
                        error in
                        if let e = error {
                            errorMessage = "\(e)"
                            popupKind = .error
                        } else {
                            newMessage = ""
                        }
                    }
                }) {
                    Text("Send")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(Color.white)
                .cornerRadius(10)
            }
        }
        .onAppear {
            chatHubDelegate.connectionDidOpenFunc = connectionDidOpen
            chatHubDelegate.connectionDidFailToOpenFunc = connectionDidFailToOpen
            chatHubDelegate.connectionDidCloseFunc = connectionDidClose
            chatHubDelegate.connectionWillReconnectFunc = connectionWillReconnect
            chatHubDelegate.connectionDidReconnectFunc = connectionDidReconnect

            chatHubConnection.on(method: "NewMessage") {(message: Message) in
                self.messages.append(message)
            }
        }
        .padding()
        .alert("Please enter your name", isPresented: .constant(popupKind == .name), actions: {
            TextField("User Name", text: $name)
            Button("OK", action: {
                popupKind = .none
                self.chatHubConnection.start()
            })
        })
        .alert("Error", isPresented: .constant(popupKind == .error), actions: {
                Button("OK", action: {
                    popupKind = .none
                    errorMessage = ""
                })
            },
               message: {
                Text(errorMessage)
            })
        .alert("Error", isPresented: .constant(popupKind == .errorRestart), actions: {
                Button("OK", action: {
                    popupKind = .name
                    errorMessage = ""
                })
            },
               message: {
                Text(errorMessage)
        })
        .alert("Connection lost", isPresented: .constant(popupKind == .reconnect), actions: {
            Button("", action: {})
        }, message: {
            Text("Reconnecting...")
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
