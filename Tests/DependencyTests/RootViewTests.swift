//
//  RootViewTests.swift
//  
//
//  Created by Andrea Tomarelli on 22/09/23.
//

import ComposableArchitecture
@testable import Dependency
import XCTest

@MainActor
class RootViewTests: XCTestCase {
    func testGG() async {
        let actor = Actor(id: .init(UUID(1)), name: "Actor")
        let movie = Movie(id: .init(UUID(1)), title: "Movie")
        
        let store = TestStore(
            initialState: RootFeature.State(
                actorsList: .init(actors: [actor]),
                actorsPath: .init([
                    .actorDetail(
                        .init(
                            actor: actor,
                            allMovies: [movie],
                            movies: [movie]
                        )
                    )
                ]),
                moviesList: .init(movies: [movie]),
                moviesPath: .init([
                    .movieDetail(
                        .init(
                            actors: [actor],
                            allActors: [actor],
                            movie: movie
                        )
                    )
                ])
            )
        ) {
            RootFeature()
        } withDependencies: {
            let storage = Storage.liveValue
            storage.actors_.upsert(Actor(id: .init(UUID(1)), name: "Actor"))
            storage.movies_.upsert(Movie(id: .init(UUID(1)), title: "Movie"))
            storage.links_.upsert(Link(id: .init(actorId: .init(UUID(1)), movieId: .init(UUID(1)))))
            $0.storage = storage
        }
        
        let actorTask = await store.send(
            .actorsPath(
                .element(id: 0, action: .actorDetail(.storage(.sync)))
            )
        )
        
        await store.receive(/RootFeature.Action.actorsPath)
        await store.receive(/RootFeature.Action.actorsPath)
        await store.receive(/RootFeature.Action.actorsPath)
        
        await store.send(
            .actorsPath(
                .element(id: 0, action: .actorDetail(.set(\.$actor, Actor(id: actor.id, name: "Modified"))))
            )
        ) {
            $0.actorsPath[id: 0] = .actorDetail(
                .init(
                    actor: Actor(id: actor.id, name: "Modified"),
                    allMovies: [movie],
                    movies: [movie]
                )
            )
        }
        
        await store.receive(/RootFeature.Action.actorsPath)
        
        await actorTask.cancel()
        
        let movieTask = await store.send(
            .moviesPath(
                .element(id: 1, action: .movieDetail(.storage(.sync)))
            )
        )

        await store.receive { action in
            guard case .moviesPath(.element(id: 1, action: .movieDetail(.storage(.linksChanged)))) = action else {
                return false
            }
            
            return true
        } assert: {
            try? (/RootFeature.Path.State.movieDetail).modify(&$0.moviesPath[id: 1]) {
                $0.actors[0].name = "Modified"
            }
        }
        
        await store.receive { action in
            guard case .moviesPath(.element(id: 1, action: .movieDetail(.storage(.movieChanged)))) = action else {
                return false
            }
            
            return true
        }
        
        await store.receive { action in
            guard case .moviesPath(.element(id: 1, action: .movieDetail(.storage(.actorsChanged)))) = action else {
                return false
            }
            
            return true
        } assert: {
            try? (/RootFeature.Path.State.movieDetail).modify(&$0.moviesPath[id: 1]) {
                $0.allActors[0].name = "Modified"
            }
        }
            
        await movieTask.cancel()
    }
}

