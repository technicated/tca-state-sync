//
//  SwiftUIView.swift
//  
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

public struct ActorsListFeature: Reducer {
    public struct State: Equatable {
        var actors: IdentifiedArrayOf<Actor>

        public init(actors: IdentifiedArrayOf<Actor> = []) {
            self.actors = actors
        }
    }

    public enum Action {
        case actorTapped(Actor)
        case delegate(Delegate)
        
        public enum Delegate {
            case goToActorDetails(Actor)
        }
    }
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .actorTapped(actor):                
                return .send(.delegate(.goToActorDetails(actor)))
            
            case .delegate:
                return .none
            }
        }
    }
}

struct ActorsListView: View {
    let store: StoreOf<ActorsListFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            if viewStore.actors.isEmpty {
                Text("No Actor registered")
                    .foregroundColor(.gray)
            } else {
                List(viewStore.actors) { `actor` in
                    Button {
                        viewStore.send(.actorTapped(`actor`))
                    } label: {
                        Text("\(`actor`.name)")
                    }
                }
            }
        }
        .navigationTitle("Actors")
    }
}

struct ActorsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {            
            ActorsListView(
                store: Store(
                    initialState: ActorsListFeature.State(actors: .mock)
                ) {
                    ActorsListFeature()
                }
            )
        }
    }
}
