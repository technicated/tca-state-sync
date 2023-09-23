//
//  ActorDetailView.swift
//  
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

public struct ActorDetailFeaure: Reducer {
    public struct State: Equatable {
        @BindingState var actor: Actor
        var allMovies: IdentifiedArrayOf<Movie>
        @BindingState var isSelectingMovie: Bool = false
        var movies: IdentifiedArrayOf<Movie>
    }
    
    public enum Action: BindableAction {
        case addMovieButtonTapped
        case binding(_ action: BindingAction<State>)
        case delegate(Delegate)
        case deleteMovies(atOffsets: IndexSet)
        case movieSelected(Movie)
        case movieSelectionCancelButtonTapped
        case movieTapped(Movie)

        public enum Delegate {
            case actorMoviesChanged(Actor, IdentifiedArrayOf<Movie>)
            case actorNameChanged(Actor)
            case goToMovie(Movie)
        }
    }
    
    public var body: some ReducerOf<Self> {
        BindingReducer()
            .onChange(of: \.actor.name) { oldValue, newValue in
                Reduce { state, action in
                    .send(.delegate(.actorNameChanged(state.actor)))
                }
            }

        Reduce { state, action in
            switch action {
            case .addMovieButtonTapped:
                state.isSelectingMovie = true
                return .none

            case .binding:
                return .none
            
            case let .deleteMovies(indices):
                state.movies.remove(atOffsets: indices)
                return .none
                
            case .delegate:
                return .none
                
            case let .movieSelected(movie):
                state.isSelectingMovie = false
                state.movies.append(movie)
                state.movies.sort { $0.title < $1.title }
                return .none
 
            case .movieSelectionCancelButtonTapped:
                state.isSelectingMovie = false
                return .none

            case let .movieTapped(movie):
                return .send(.delegate(.goToMovie(movie)))
            }
        }
        .onChange(of: \.movies) { oldValue, newValue in
            Reduce { state, action in
                .send(.delegate(.actorMoviesChanged(state.actor, state.movies)))
            }
        }
    }
}

struct ActorDetailView: View {
    struct ViewState: Equatable {
        @BindingViewState var actor: Actor
        var allMovies: IdentifiedArrayOf<Movie>
        @BindingViewState var isSelectingMovie: Bool
        var movies: IdentifiedArrayOf<Movie>
        var navigationTitle: String
    
        init(store: BindingViewStore<ActorDetailFeaure.State>) {
            self._actor = store.$actor
            self.allMovies = store.allMovies
            self._isSelectingMovie = store.$isSelectingMovie
            self.movies = store.movies
            self.navigationTitle = store.actor.name.isEmpty
                ? "Unnamed Actor"
                : store.actor.name
        }
    }
    
    let store: StoreOf<ActorDetailFeaure>

    var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            List {
                Section {
                    TextField("Name", text: viewStore.$actor.name)
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
       }
    }
}

struct ActorDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ActorDetailView(
                store: Store(
                    initialState: ActorDetailFeaure.State(
                        actor: .mock,
                        allMovies: .mock,
                        movies: []
                    )
                ) {
                    ActorDetailFeaure()
                }
            )
        }
    }
}
