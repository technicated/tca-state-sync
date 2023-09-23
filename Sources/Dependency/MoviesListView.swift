//
//  MoviesListView.swift
//
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

struct MoviesListFeature: Reducer {
    struct State: Equatable {
        var movies: IdentifiedArrayOf<Movie>
    }

    enum Action {
        case delegate(Delegate)
        case movieTapped(Movie)
        case storage(Storage.Action)

        enum Delegate {
            case goToMovieDetails(Movie)
        }
    }

    struct Storage: Reducer {
        enum Action {
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
                case let .moviesChanged(.initial(movies)):
                    state.movies = .init(uniqueElements: movies.values)
                    return .none

                case let .moviesChanged(.changes(values, insertions, modifications, deletions)):
                    insertions
                        .compactMap { values[$0] }
                        .forEach { state.movies.append($0) }

                    deletions
                        .forEach { state.movies.remove(id: $0) }

                    modifications
                        .compactMap { values[$0] }
                        .forEach { state.movies[id: $0.id] = $0 }

                    return .none

                case .sync:
                    return .run { send in
                        for await change in storage.movies_.observeAll() {
                            await send(.moviesChanged(change))
                        }
                    }
                }
            }
            .onChange(of: \.movies) { oldValue, newValue in
                Reduce { state, action in
                    state.movies.sort { $0.title < $1.title }
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
            
            case .delegate:
                return .none
                
            case let .movieTapped(movie):
                return .send(.delegate(.goToMovieDetails(movie)))
         
            case .storage:
                return .none
            }
        }
    }
}

struct MoviesListView: View {
    let store: StoreOf<MoviesListFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            if viewStore.movies.isEmpty {
                Text("No Movie registered")
                    .foregroundColor(.gray)
            } else {
                List(viewStore.movies) { movie in
                    Button {
                        viewStore.send(.movieTapped(movie))
                    } label: {
                        Text("\(movie.title)")
                    }
                }
            }
        }
        .navigationTitle("Movies")
        .task { await store.send(.storage(.sync)).finish() }
    }
}

struct MoviesListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MoviesListView(
                store: Store(
                    initialState: MoviesListFeature.State(
                        movies: [.mock]
                    )
                ) {
                    MoviesListFeature()
                }
            )
        }
    }
}
