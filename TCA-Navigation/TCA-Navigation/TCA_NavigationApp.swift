//
//  TCA_NavigationApp.swift
//  TCA-Navigation
//
//  Created by Andrea Tomarelli on 02/09/23.
//

import ComposableArchitecture
import Delegates
import SwiftUI

@main
struct TCA_NavigationApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(
                store: Store(
                    initialState: RootFeature.State(
                        actorsList: .init(
                            actors: [Delegates.Actor(id: .init(), name: "Andrea")]
                        )
                    )
                ) {
                    RootFeature()
                }
            )
            /*ContentView(
                store: .init(initialState: .init()) {
                    ParentFeature()
                }
            )*/
        }
    }
}
