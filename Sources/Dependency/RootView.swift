//
//  RootView.swift
//  
//
//  Created by Andrea Tomarelli on 12/09/23.
//

import ComposableArchitecture
import SwiftUI

struct RootFeature: Reducer {
    struct State {
        var actorsList: ActorsListFeature.State = .init(actors: [])
        var actorsPath: StackState<Path.State> = .init()
        var moviesList: MoviesListFeature.State = .init(movies: [])
        var moviesPath: StackState<Path.State> = .init()
    }
    
    enum Action {
        case actorsList(ActorsListFeature.Action)
        case actorsPath(StackAction<Path.State, Path.Action>)
        case moviesList(MoviesListFeature.Action)
        case moviesPath(StackAction<Path.State, Path.Action>)
    }
    
    struct Path: Reducer {
        enum State {
            case actorDetail(ActorDetailFeature.State)
            case movieDetail(MovieDetailFeature.State)
        }
        
        enum Action {
            case actorDetail(ActorDetailFeature.Action)
            case movieDetail(MovieDetailFeature.Action)
        }
        
        var body: some ReducerOf<Self> {
            Scope(state: /State.actorDetail, action: /Action.actorDetail) {
                ActorDetailFeature()
            }
            
            Scope(state: /State.movieDetail, action: /Action.movieDetail) {
                MovieDetailFeature()
            }
        }
    }
    
    var body: some ReducerOf<Self> {
        Scope(state: \.actorsList, action: /Action.actorsList) {
            ActorsListFeature()
        }
        
        Scope(state: \.moviesList, action: /Action.moviesList) {
            MoviesListFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .actorsList(.delegate(.goToActorDetails(actor))):
                state.actorsPath.append(.actorDetail(.init(actor: actor)))
                return .none

            case .actorsList:
                return .none
 
            case let .actorsPath(.element(_, .actorDetail(.delegate(.goToMovie(movie))))):
                state.actorsPath.append(.movieDetail(.init(movie: movie)))
                return .none
                
           case let .actorsPath(.element(_, .movieDetail(.delegate(.goToActor(actor))))):
                state.actorsPath.append(.actorDetail(.init(actor: actor)))
                return .none
                               
            case .actorsPath:
                return .none

            case let .moviesList(.delegate(.goToMovieDetails(movie))):
                state.moviesPath.append(.movieDetail(.init(movie: movie)))
                return .none

            case .moviesList:
                return .none
                
            case let .moviesPath(.element(_, .actorDetail(.delegate(.goToMovie(movie))))):
                state.moviesPath.append(.movieDetail(.init(movie: movie)))
                return .none
                
           case let .moviesPath(.element(_, .movieDetail(.delegate(.goToActor(actor))))):
                state.moviesPath.append(.actorDetail(.init(actor: actor)))
                return .none
                               
            case .moviesPath:
                return .none
            }
        }
        .forEach(\.actorsPath, action: /Action.actorsPath) {
            Path()
        }
        .forEach(\.moviesPath, action: /Action.moviesPath) {
            Path()
        }
    }
}

struct RootView: View {
    let store: StoreOf<RootFeature>

    var body: some View {
        TabView {
            NavigationStackStore(
                store.scope(
                    state: \.actorsPath,
                    action: { .actorsPath($0) }
                )
            ) {
                ActorsListView(
                    store: store.scope(
                        state: \.actorsList,
                        action: { .actorsList($0) }
                    )
                )
            } destination: { state in
                switch state {
                case .actorDetail:
                    CaseLet(
                        /RootFeature.Path.State.actorDetail,
                         action: RootFeature.Path.Action.actorDetail,
                         then: ActorDetailView.init(store:))

                case .movieDetail:
                    CaseLet(
                        /RootFeature.Path.State.movieDetail,
                         action: RootFeature.Path.Action.movieDetail,
                         then: MovieDetailView.init(store:))
                }
            }
            .tabItem {
                Text("Actors")
            }

            NavigationStackStore(
                store.scope(
                    state: \.moviesPath,
                    action: { .moviesPath($0) }
                )
            ) {
                MoviesListView(
                    store: store.scope(
                        state: \.moviesList,
                        action: { .moviesList($0) }
                    )
                )
            } destination: { state in
                switch state {
                case .actorDetail:
                    CaseLet(
                        /RootFeature.Path.State.actorDetail,
                         action: RootFeature.Path.Action.actorDetail,
                         then: ActorDetailView.init(store:))

                case .movieDetail:
                    CaseLet(
                        /RootFeature.Path.State.movieDetail,
                         action: RootFeature.Path.Action.movieDetail,
                         then: MovieDetailView.init(store:))
                }
            }
            .tabItem {
                Text("Movies")
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            store: Store(
                initialState: RootFeature.State(
                    actorsList: .init(actors: [.mock]),
                    moviesList: .init(movies: [.mock])
                )
            ) {
                RootFeature()
            }
        )
    }
}
