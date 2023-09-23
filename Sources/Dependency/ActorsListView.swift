//
//  ActorsListView.swift
//
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

struct ActorsListFeature: Reducer {
    struct State: Equatable {
        var actors: IdentifiedArrayOf<Actor>
    }

    enum Action {
        case actorTapped(Actor)
        case delegate(Delegate)
        case storage(Storage.Action)

        enum Delegate {
            case goToActorDetails(Actor)
        }
    }

    struct Storage: Reducer {
        enum Action {
            case actorsChanged(CollectionChange<Actor>)
            case sync
        }
        
        @Dependency(\.continuousClock)
        var clock
        
        @Dependency(\.storage)
        var storage

        var body: some Reducer<State, Action> {
            Reduce { state, action in
                switch action {
                case let .actorsChanged(.initial(actors)):
                    state.actors = .init(uniqueElements: actors.values)
                    return .none

                case let .actorsChanged(.changes(values, insertions, modifications, deletions)):
                    insertions
                        .compactMap { values[$0] }
                        .forEach { state.actors.append($0) }

                    deletions
                        .forEach { state.actors.remove(id: $0) }

                    modifications
                        .compactMap { values[$0] }
                        .forEach { state.actors[id: $0.id] = $0 }

                    return .none

                case .sync:
                    return .run { send in
                        for await change in storage.actors_.observeAll() {
                            await send(.actorsChanged(change))
                        }
                    }
                }
            }
            .onChange(of: \.actors) { oldValue, newValue in
                Reduce { state, action in
                    state.actors.sort { $0.name < $1.name }
                    return .none
                }
            }
        }
    }
    
    @Dependency(\.storage)
    var storage
    
    var body: some ReducerOf<Self> {
        Scope(state: \.self, action: /Action.storage) {
            Storage()
        }

        Reduce { state, action in
            switch action {
            case let .actorTapped(actor):
                return .send(.delegate(.goToActorDetails(actor)))
            
            case .delegate:
                return .none

            case .storage:
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
        .task { await store.send(.storage(.sync)).finish() }
    }
}

struct ActorsListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ActorsListView(
                store: Store(
                    initialState: ActorsListFeature.State(
                        actors: [.mock]
                    )
                ) {
                    ActorsListFeature()
                }
            )
        }
    }
}
