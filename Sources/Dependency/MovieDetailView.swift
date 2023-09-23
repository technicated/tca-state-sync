//
//  MovieDetailView.swift
//
//
//  Created by Andrea Tomarelli on 12/09/23.
//

import ComposableArchitecture
import SwiftUI

struct MovieDetailFeature: Reducer {
    struct State: Equatable {
        var actors: IdentifiedArrayOf<Actor> = []
        var allActors: IdentifiedArrayOf<Actor> = []
        var isDeleted: Bool = false
        @BindingState var isSelectingActor: Bool = false
        @BindingState var movie: Movie
    }
    
    enum Action: BindableAction {
        case actorSelected(Actor)
        case actorSelectionCancelButtonTapped
        case actorTapped(Actor)
        case addActorButtonTapped
        case binding(_ action: BindingAction<State>)
        case delegate(Delegate)
        case deleteActors(atOffsets: IndexSet)
        case storage(Storage.Action)
        
        enum Delegate {
            case goToActor(Actor)
        }
    }
    
    struct Storage: Reducer {
        enum Action {
            case actorsChanged(CollectionChange<Actor>)
            case linksChanged(CollectionChange<Link>)
            case movieChanged(ObjectChange<Movie>)
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
                    state.allActors = .init(uniqueElements: actors.values)
                    return .none
                    
                case let .actorsChanged(.changes(actors, _, modifications, deletions)):
                    state.allActors = .init(uniqueElements: actors.values)

                    let actorsIds = state.actors.ids

                    modifications
                        .filter { actorsIds.contains($0) }
                        .forEach { state.actors[id: $0] = actors[$0] }
                
                    deletions.forEach {
                        state.actors.remove(id: $0)
                    }
                    
                    return .none
                     
                case .linksChanged(.initial):
                    return .none

                case let .linksChanged(.changes(_, insertions, _, deletions)):
                    let movieId = state.movie.id
                    let actors = storage.actors_.all()

                    state.actors.append(
                        contentsOf: insertions
                            .filter { $0.movieId == movieId }
                            .compactMap { actors[$0.actorId] }
                    )
                    
                    deletions
                        .filter { $0.movieId == movieId }
                        .forEach { state.actors.remove(id: $0.actorId) }

                    return .none
                                        
                case .movieChanged(.deleted):
                    state.isDeleted = true
                    return .none

                case let .movieChanged(.initial(movie)),
                    let .movieChanged(.inserted(movie)),
                    let .movieChanged(.modified(movie)):
                    state.movie = movie
                    return .none
                    
                case .sync:
                    return .merge(
                        .run { [movieId = state.movie.id] send in
                            for await change in storage.movies_.observeObject(movieId) {
                                await send(.movieChanged(change))
                            }
                        },
                        .run { send in
                            for await change in storage.actors_.observeAll() {
                                await send(.actorsChanged(change))
                            }
                        },
                        .run { send in
                            for await change in storage.links_.observeAll() {
                                await send(.linksChanged(change))
                            }
                        }
                    )
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
        
        BindingReducer()
            .onChange(of: \.movie.title) { oldValue, newValue in
                Reduce { state, action in
                    storage.upsertMovie(state.movie)
                    return .none
                }
            }
        
        Reduce { state, action in
            switch action {
            case let .actorSelected(actor):
                state.isSelectingActor = false
                state.actors.append(actor)

                storage.links_.upsert(
                    Link(
                        id: .init(
                            actorId: actor.id,
                            movieId: state.movie.id
                        )
                    )
                )

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

            case .delegate:
                return .none

            case let .deleteActors(indices):
                var ids = state.actors.map(\.id)
                state.actors.remove(atOffsets: indices)
                ids.removeAll {
                    state.actors.map(\.id).contains($0)
                }

                for id in ids {
                    storage.links_.delete(
                        Link(
                            id: .init(
                                actorId: id,
                                movieId: state.movie.id
                            )
                        )
                    )
                }

                return .none


            case .storage:
                return .none
            }
        }
    }
}

struct MovieDetailView: View {
    struct ViewState: Equatable {
        let actors: IdentifiedArrayOf<Actor>
        let allActors: IdentifiedArrayOf<Actor>
        let isDisabled: Bool
        @BindingViewState var isSelectingActor: Bool
        @BindingViewState var movieTitle: String
        let navigationTitle: String

        init(state: BindingViewStore<MovieDetailFeature.State>) {
            self.actors = state.actors
            self.allActors = state.allActors
            self.isDisabled = state.isDeleted
            self._isSelectingActor = state.$isSelectingActor
            self._movieTitle = state.$movie.title
            self.navigationTitle = (state.isDeleted ? "[deleted] " : "") + (state.movie.title.isEmpty ? "Untitled Movie" : state.movie.title)
        }
    }
    
    let store: StoreOf<MovieDetailFeature>
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            List {
                Section {
                    TextField(
                        "Name",
                        text: viewStore.$movieTitle
                    )
                } header: {
                    Text("Name")
                }

                Section {
                    ForEach(viewStore.actors) { actor in
                        Button("\(actor.name)") {
                            viewStore.send(.actorTapped(actor))
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
                    List(viewStore.allActors) { actor in
                        Button("\(actor.name)") {
                            viewStore.send(.actorSelected(actor))
                        }
                    }
                    .navigationTitle("Select Movie")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                viewStore.send(.actorSelectionCancelButtonTapped)
                            }
                        }
                    }
                }
            }
            .disabled(viewStore.isDisabled)
            .task { await viewStore.send(.storage(.sync)).finish() }
        }
    }
}

struct MovieDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MovieDetailView(
                store: Store(
                    initialState: MovieDetailFeature.State(
                        actors: [.mock],
                        movie: .mock
                    )
                ) {
                    MovieDetailFeature()
                }
            )
        }
    }
}
