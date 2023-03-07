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

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var newMessage = ""
    @State private var showNamePopup = true
    @State private var name = ""
    private var chatHubConnection: HubConnection

    init() {
        chatHubConnection = HubConnectionBuilder(url: URL(string: "http://192.168.86.25:5000/chat")!)
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
                    chatHubConnection.send(method: "Broadcast", name, newMessage)
                    newMessage = ""
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
            chatHubConnection.on(method: "NewMessage") {(name: String, text: String) in
                self.messages.append(Message(name: name, text: text))
            }
        }
        .padding()
        .alert("Please enter your name", isPresented: $showNamePopup, actions: {
            TextField("User Name", text: $name)
            Button("OK", action: {
                showNamePopup = false
                self.chatHubConnection.start()
            })
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
