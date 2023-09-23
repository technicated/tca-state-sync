//
//  ActorDetailView.swift
//  
//
//  Created by Andrea Tomarelli on 12/09/23.
//

import ComposableArchitecture
import SwiftUI

struct ActorDetailFeature: Reducer {
    struct State: Equatable {
        @BindingState var actor: Actor
        var allMovies: IdentifiedArrayOf<Movie> = []
        var isDeleted: Bool = false
        @BindingState var isSelectingMovie: Bool = false
        var movies: IdentifiedArrayOf<Movie> = []
    }
    
    enum Action: BindableAction {
        case addMovieButtonTapped
        case binding(_ action: BindingAction<State>)
        case delegate(Delegate)
        case deleteMovies(atOffsets: IndexSet)
        case movieSelected(Movie)
        case movieSelectionCancelButtonTapped
        case movieTapped(Movie)
        case storage(Storage.Action)
        
        enum Delegate {
            case goToMovie(Movie)
        }
    }
    
    struct Storage: Reducer {
        enum Action {
            case actorChanged(ObjectChange<Actor>)
            case linksChanged(CollectionChange<Link>)
            case moviesChanged(CollectionChange<Movie>)
            case sync
        }

        @Dependency(\.continuousClock)
        var clock

        @Dependency(\.storage)
        var storage

        var body: some Reducer<State, Action> {
            Reduce { state, action in
                switch action {
                case .actorChanged(.deleted):
                    state.isDeleted = true
                    return .none

                case let .actorChanged(.initial(actor)),
                    let .actorChanged(.inserted(actor)),
                    let .actorChanged(.modified(actor)):
                    state.actor = actor
                    return .none

                case .linksChanged(.initial):
                    return .none
                    
                case let .linksChanged(.changes(_, insertions, _, deletions)):
                    let actorId = state.actor.id
                    let movies = storage.movies_.all()

                    state.movies.append(
                        contentsOf: insertions
                            .filter { $0.actorId == actorId }
                            .compactMap { movies[$0.movieId] }
                    )
                    
                    deletions
                        .filter { $0.actorId == actorId }
                        .forEach { state.movies.remove(id: $0.movieId) }

                    return .none
                    
                case let .moviesChanged(.initial(movies)):
                    state.allMovies = .init(uniqueElements: movies.values)
                    return .none
                    
                case let .moviesChanged(.changes(movies, _, modifications, deletions)):
                    state.allMovies = .init(uniqueElements: movies.values)

                    let moviesIds = state.movies.ids

                    modifications
                        .filter { moviesIds.contains($0) }
                        .forEach { state.movies[id: $0] = movies[$0] }
                
                    deletions.forEach {
                        state.movies.remove(id: $0)
                    }
                    
                    return .none
 
                case .sync:
                    return .merge(                        
                        .run { [actorId = state.actor.id] send in
                            for await change in storage.actors_.observeObject(actorId) {
                                await send(.actorChanged(change))
                            }
                        },
                        .run { send in
                            for await change in storage.movies_.observeAll() {
                                await send(.moviesChanged(change))
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
            .onChange(of: \.actor.name) { oldValue, newValue in
                Reduce { state, action in
                    storage.upsertActor(state.actor)
                    return .none
                }
            }
        
        Reduce { state, action in
            switch action {
            case .addMovieButtonTapped:
                state.isSelectingMovie = true
                return .none

            case .binding:
                return .none

            case .delegate:
                return .none
            
            case let .deleteMovies(indices):
                var ids = state.movies.map(\.id)
                state.movies.remove(atOffsets: indices)
                ids.removeAll {
                    state.movies.map(\.id).contains($0)
                }
              
                for id in ids {
                    storage.links_.delete(
                        Link(
                            id: .init(
                                actorId: state.actor.id,
                                movieId: id
                            )
                        )
                    )
                }
                
                return .none
                
            case let .movieSelected(movie):
                state.isSelectingMovie = false
                state.movies.append(movie)
                
                storage.links_.upsert(
                    Link(
                        id: .init(
                            actorId: state.actor.id,
                            movieId: movie.id
                        )
                    )
                )
                
                return .none
            
            case .movieSelectionCancelButtonTapped:
                state.isSelectingMovie = false
                return .none
            
            case let .movieTapped(movie):
                return .send(.delegate(.goToMovie(movie)))

            case .storage:
                return .none
            }
        }
    }
}

struct ActorDetailView: View {
    struct ViewState: Equatable {
        @BindingViewState var actorName: String
        let allMovies: IdentifiedArrayOf<Movie>
        let isDisabled: Bool
        let movies: IdentifiedArrayOf<Movie>
        @BindingViewState var isSelectingMovie: Bool
        let navigationTitle: String

        init(state: BindingViewStore<ActorDetailFeature.State>) {
            self._actorName = state.$actor.name
            self.allMovies = state.allMovies
            self.isDisabled = state.isDeleted
            self._isSelectingMovie = state.$isSelectingMovie
            self.movies = state.movies
            self.navigationTitle = (state.isDeleted ? "[deleted] " : "") + (state.actor.name.isEmpty ? "Unnamed Actor" : state.actor.name)
        }
    }
    
    let store: StoreOf<ActorDetailFeature>
    
    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            List {
                Section {
                    TextField(
                        "Name",
                        text: viewStore.$actorName
                    )
                } header: {
                    Text("Name")
                }

                Section {
                    ForEach(viewStore.movies) { movie in
                        Button("\(movie.title)") {
                            viewStore.send(.movieTapped(movie))
                        }
                    }
                    .onDelete {
                        viewStore.send(.deleteMovies(atOffsets: $0))
                    }

                    Button("Add Movie...") {
                        viewStore.send(.addMovieButtonTapped)
                    }
                } header: {
                    Text("Starring In")
                }
            }
            .navigationTitle("\(viewStore.navigationTitle)")
            .sheet(isPresented: viewStore.$isSelectingMovie) {
                NavigationStack {
                    List(viewStore.allMovies) { movie in
                        Button("\(movie.title)") {
                            viewStore.send(.movieSelected(movie))
                        }
                    }
                    .navigationTitle("Select Movie")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                viewStore.send(.movieSelectionCancelButtonTapped)
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

struct ActorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ActorDetailView(
                store: Store(
                    initialState: ActorDetailFeature.State(
                        actor: .mock,
                        movies: [.mock]
                    )
                ) {
                    ActorDetailFeature()
                }
            )
        }
    }
}
