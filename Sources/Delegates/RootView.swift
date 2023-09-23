//
//  RootView.swift
//
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import SwiftUI

public struct RootFeature: Reducer {
    public struct State {
        var actions: [(UUID, Action)]
        var actorsList: ActorsListFeature.State
        var actorsPath: StackState<Path.State>

        public init(
            actions: [(UUID, Action)] = [],
            actorsList: ActorsListFeature.State = .init(),
            actorsPath: StackState<Path.State> = .init()
        ) {
            self.actions = actions
            self.actorsList = actorsList
            self.actorsPath = actorsPath
        }
    }

    public enum Action {
        case actorsList(ActorsListFeature.Action)
        case actorsPath(StackAction<Path.State, Path.Action>)
    }
    
    public struct Path: Reducer {
        public enum State {
            case actor(ActorDetailFeaure.State)
            case movie(MovieDetailFeaure.State)
        }
        
        public enum Action {
            case actor(ActorDetailFeaure.Action)
            case movie(MovieDetailFeaure.Action)
        }
    
        public var body: some ReducerOf<Self> {
            Scope(state: /State.actor, action: /Action.actor) {
                ActorDetailFeaure()
            }

            Scope(state: /State.movie, action: /Action.movie) {
                MovieDetailFeaure()
            }
        }
    }
    
    public init() { }
    
    public var body: some ReducerOf<Self> {
        Scope(state: \.actorsList, action: /Action.actorsList) {
            ActorsListFeature()
        }
        
        Reduce { state, action in
            switch action {
            case let .actorsList(.delegate(.goToActorDetails(actor))):
                state.actorsPath.append(.actor(ActorDetailFeaure.State(actor: actor, allMovies: .mock, movies: .mock)))
                return .none

            case .actorsList:
                return .none

            case let .actorsPath(.element(id: _, action: .actor(.delegate(.actorNameChanged(actor))))):
                state.actorsList.actors[id: actor.id]?.name = actor.name

                for idx in state.actorsPath.ids {
                    guard case var .actor(s) = state.actorsPath[id: idx] else { continue }
                    s.actor.name = actor.name
                    state.actorsPath[id: idx] = .actor(s)
                }

                return .none

            case let .actorsPath(.element(id: _, action: .actor(.delegate(.goToMovie(movie))))):
                state.actorsPath.append(.movie(MovieDetailFeaure.State(actors: .mock, allActors: .mock, movie: movie)))
                return .none
                
            case let .actorsPath(.element(id: _, action: .movie(.delegate(.goToActor(actor))))):
                state.actorsPath.append(.actor(ActorDetailFeaure.State(actor: actor, allMovies: .mock, movies: .mock)))
                return .none
                
            case .actorsPath:
                return .none
            }
        }
        .forEach(\.actorsPath, action: /Action.actorsPath) {
            Path()
        }
        
        Reduce { state, action in
            state.actions.append((UUID(), action))
            return .none
        }
    }
}


public struct RootView: View {
    let store: StoreOf<RootFeature>

    public init(store: StoreOf<RootFeature>) {
        self.store = store
    }
    
    public var body: some View {
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
                case .actor:
                    CaseLet(
                        /RootFeature.Path.State.actor,
                         action: RootFeature.Path.Action.actor,
                         then: ActorDetailView.init(store:)
                    )
                    
                case .movie:
                    CaseLet(
                        /RootFeature.Path.State.movie,
                         action: RootFeature.Path.Action.movie,
                         then: MovieDetailView.init(store:)
                    )
                }
            }
            .tabItem {
                Text("Actors")
            }
            
            WithViewStore(store, observe: \.actions, removeDuplicates: { $0.map(\.0) == $1.map(\.0) }) { viewStore in
                List(viewStore.state, id: \.0) {
                    Text(String(describing: $1))
                }
            }
            .tabItem {
                Text("B")
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView(
            store: Store(
                initialState: RootFeature.State(
                    actorsList: .init(actors: .mock)
                )
            ) {
                RootFeature()
            }
        )
    }
}
