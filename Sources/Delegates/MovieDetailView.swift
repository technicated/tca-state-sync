//
//  MovieDetailView.swift
//
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

public struct MovieDetailFeaure: Reducer {
    public struct State: Equatable {
        var actors: IdentifiedArrayOf<Actor>
        var allActors: IdentifiedArrayOf<Actor>
        @BindingState var isSelectingActor: Bool = false
        @BindingState var movie: Movie
    }
    
    public enum Action: BindableAction {
        case actorSelected(Actor)
        case actorSelectionCancelButtonTapped
        case actorTapped(Actor)
        case addActorButtonTapped
        case binding(_ action: BindingAction<State>)
        case delegate(Delegate)
        case deleteActors(atOffsets: IndexSet)

        public enum Delegate {
            case goToActor(Actor)
            case movieActorsChanged(Movie, IdentifiedArrayOf<Actor>)
            case movieTitleChanged(Movie)
        }
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.movie.title) { oldValue, newValue in
                Reduce { state, action in
                    .send(.delegate(.movieTitleChanged(state.movie)))
                }
            }

        Reduce { state, action in
            switch action {
            case let .actorSelected(actor):
                state.isSelectingActor = false
                state.actors.append(actor)
                state.actors.sort { $0.name < $1.name }
                return .none
 
            case .actorSelectionCancelButtonTapped:
                state.isSelectingActor = false
                return .none

            case let .actorTapped(actor):
                return .send(.delegate(.goToActor(actor)))
                
            case .addActorButtonTapped:
                state.isSelectingActor = true
                return .none

            case .binding:
                return .none
            
            case let .deleteActors(indices):
                state.actors.remove(atOffsets: indices)
                return .none
                
            case .delegate:
                return .none
            }
        }
        .onChange(of: \.actors) { oldValue, newValue in
            Reduce { state, action in
                .send(.delegate(.movieActorsChanged(state.movie, state.actors)))
            }
        }
    }
}

struct MovieDetailView: View {
    struct ViewState: Equatable {
        var actors: IdentifiedArrayOf<Actor>
        var allActors: IdentifiedArrayOf<Actor>
        @BindingViewState var isSelectingActor: Bool
        @BindingViewState var movie: Movie
        var navigationTitle: String
    
        init(store: BindingViewStore<MovieDetailFeaure.State>) {
            self.actors = store.actors
            self.allActors = store.allActors
            self._isSelectingActor = store.$isSelectingActor
            self._movie = store.$movie
            self.navigationTitle = store.movie.title.isEmpty
                ? "Unnamed Movie"
                : store.movie.title
        }
    }
    
    let store: StoreOf<MovieDetailFeaure>

    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            List {
                Section {
                    TextField("Title", text: viewStore.$movie.title)
                } header: {
                    Text("Title")
                }

                Section {
                    ForEach(viewStore.actors) { `actor` in
                        Button("\(`actor`.name)") {
                            viewStore.send(.actorTapped(`actor`))
                        }
                    }
                    .onDelete {
                        viewStore.send(.deleteActors(atOffsets: $0))
                    }

                    Button("Add Actor...") {
                        viewStore.send(.addActorButtonTapped)
                    }
                } header: {
                    Text("Starring")
                }
            }
            .navigationTitle("\(viewStore.navigationTitle)")
            .sheet(isPresented: viewStore.$isSelectingActor) {
                NavigationStack {
                    List(viewStore.allActors) { `actor` in
                        Button("\(`actor`.name)") {
                            viewStore.send(.actorSelected(`actor`))
                        }
                    }
                    .navigationTitle("Select Actor")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                viewStore.send(.actorSelectionCancelButtonTapped)
                            }
                        }
                    }
                }
            }
       }
    }
}

struct MovieDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MovieDetailView(
                store: Store(
                    initialState: MovieDetailFeaure.State(
                        actors: [],
                        allActors: .mock,
                        movie: .mock
                    )
                ) {
                    MovieDetailFeaure()
                }
            )
        }
    }
}
