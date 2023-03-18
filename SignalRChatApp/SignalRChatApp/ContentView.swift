//
//  ContentView.swift
//  SignalRChatApp
//
//  Created by Pawel Kadluczka on 2/25/23.
//

import SwiftUI
import SignalRClient

struct Message: Hashable {
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

    func connectionDidOpen(hubConnection: SignalRClient.HubConnection) {
        connectionDidOpenFunc?(hubConnection)
    }

    func connectionDidFailToOpen(error: Error) {
        connectionDidFailToOpenFunc?(error)
    }

    func connectionDidClose(error: Error?) {
        connectionDidCloseFunc?(error)
    }
}

struct ContentView: View {
    enum PopupKind {
        case none
        case name
        case error
        case errorRestart
    }

    @State private var popupKind: PopupKind = .name
    @State private var errorMessage = ""
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var name = ""
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

    init() {
        chatHubConnection = HubConnectionBuilder(url: URL(string: "http://192.168.86.25:5000/chat")!)
            .withHubConnectionDelegate(delegate: chatHubDelegate)
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
                    chatHubConnection.send(method: "Broadcast", name, newMessage) {
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

            chatHubConnection.on(method: "NewMessage") {(name: String, text: String) in
                self.messages.append(Message(name: name, text: text))
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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
