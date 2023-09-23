//
//  ActorView.swift
//  TCA-Navigation
//
//  Created by Andrea Tomarelli on 02/09/23.
//

import ComposableArchitecture
import SwiftUI

struct ActorDetailFeature: Reducer {
    struct State: Equatable {
        @BindingState var actor: Actor
        var movies: [Movie]
        var value: Int = -1
    }

    enum Action: BindableAction {
        case binding(_ action: BindingAction<State>)
        case delegate(Delegate)
        case editValueButtonTapped
        case syncValue(Int)
        case task
        
        enum Delegate {
            case actorNameChanged(String)
            case goToActor
        }
    }
    
    @Dependency(\.value) var value    
    
    var body: some ReducerOf<Self> {
        BindingReducer().onChange(of: \.actor.name) { oldValue, newValue in
            Reduce { state, action in
                    .send(.delegate(.actorNameChanged(state.actor.name)))
            }
        }
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .delegate:
                return .none

            case .editValueButtonTapped:
                self.value.set(Int.random(in: 1 ... 1000))
                return .none

            case let .syncValue(value):
                state.value = value
                return .none
                
            case .task:
                return .run { send in
                    for await value in self.value.stream() {
                        await send(.syncValue(value))
                    }
                }
            }
        }
    }
}

extension ActorDetailFeature.State {
    static let mock: Self = .init(
        actor: .init(
            id: .init(UUID()),
            name: "Mark Hamill"
        ),
        movies: [
            .init(
                id: .init(UUID()),
                title: "Star Wars: A New Hope"
            ),
            .init(
                id: .init(UUID()),
                title: "Star Wars: The Empire Strikes Back"
            )
        ]
    )
}

struct ActorDetailView: View {
    let store: StoreOf<ActorDetailFeature>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            List {
                Section("GO!") {
                    Button("Go to Actor") {
                        viewStore.send(.delegate(.goToActor))
                    }
                    
                    Button("Edit value \(viewStore.value)") {
                        viewStore.send(.editValueButtonTapped)
                    }
                }

                Section("Name") {
                    TextField("Name", text: viewStore.$actor.name)
                }
                
                Section {
                    ForEach(viewStore.movies) {
                        Text("\($0.title)")
                    }
                } header: {
                    HStack {
                        Text("Starring in")
                        Spacer()
                        
                        /*Button("+") {
                            viewStore.send(.addMovieButtonTapped)
                        }*/
                    }
                }
            }
            .navigationTitle("Actor: \(viewStore.actor.name)")
            .task { await viewStore.send(.task).finish() }
        }
    }
}

struct ActorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ActorDetailView(
                store: Store(initialState: .mock) {
                    ActorDetailFeature()
                }
            )
        }
    }
}
