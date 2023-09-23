//
//  Storage.swift
//
//
//  Created by Andrea Tomarelli on 12/09/23.
//

import Combine
import ComposableArchitecture
import Foundation
import Tagged

extension Dictionary where Value: Equatable {
    func diff(oldValue: Self) -> (insertions: Set<Key>, modifications: Set<Key>, deletions: Set<Key>) {
        var insertions: Set<Key> = []
        var modifications: Set<Key> = []
        var deletions: Set<Key> = []

        for k in self.keys {
            if !oldValue.keys.contains(k) {
                insertions.insert(k)
            } else if oldValue[k] != self[k] {
                modifications.insert(k)
            }
        }

        for k in oldValue.keys {
            if !self.keys.contains(k) {
                deletions.insert(k)
            } else if oldValue[k] != self[k] {
                modifications.insert(k)
            }
        }
        
        return (insertions, modifications, deletions)
    }
}

enum CollectionChange<Element: Identifiable> {
    case changes(
        values: [Element.ID: Element],
        insertions: Set<Element.ID>,
        modifications: Set<Element.ID>,
        deletions: Set<Element.ID>
    )
    case initial([Element.ID: Element])
}

enum ObjectChange<Element: Identifiable> {
    case deleted
    case initial(Element)
    case inserted(Element)
    case modified(Element)
}

struct Resource<T: Identifiable> {
    var all: () -> [T.ID: T]
    var delete: (T) -> Void
    var object: (T.ID) -> T?
    var observeAll: () -> AsyncStream<CollectionChange<T>>
    var observeObject: (T.ID) -> AsyncStream<ObjectChange<T>>
    var upsert: (T) -> Void
}

struct Storage {
    var actors: Resource<Actor>
    var movies: Resource<Movie>
    var links: Resource<Link>
}

private extension Storage {
    static func defaultValue(
        actors: [Actor.ID: Actor] = [:],
        movies: [Movie.ID: Movie] = [:],
        links: [Movie.ID: Set<Actor.ID>] = [:]
    ) -> Storage {
        let actors = CurrentValueSubject<[Actor.ID: Actor], Never>(actors)
        let movies = CurrentValueSubject<[Movie.ID: Movie], Never>(movies)
        let links = CurrentValueSubject<[Movie.ID: Set<Actor.ID>], Never>(links)

        func pipeline1<T: Equatable & Identifiable, P: Publisher<[T.ID: T], Never>>(source: P) -> AsyncStream<CollectionChange<T>> {
            source
                .scan(Optional<([T.ID: T], CollectionChange<T>?)>.none) { carry, items in
                    switch carry {
                    case .none:
                        return (items, .initial(items))
                    case let .some(prev):
                        let (insertions, modifications, deletions) = items.diff(oldValue: prev.0)
                        return insertions.isEmpty && modifications.isEmpty && deletions.isEmpty
                            ? (items, nil)
                            : (items, .changes(values: items, insertions: insertions, modifications: modifications, deletions: deletions))
                    }
                }
                .compactMap { $0?.1 }
                .values
                .eraseToStream()
        }
        
        func pipeline2<T: Equatable & Identifiable, P: Publisher<[T.ID: T], Never>>(source: P, id: T.ID) -> AsyncStream<ObjectChange<T>> {
            source
                .map { $0[id] }
                .scan(Optional<(T?, ObjectChange<T>?)>.none) { carry, item in
                    switch carry {
                    case .none:
                        return item.map { ($0, .initial($0)) }
                    case let .some(prev):
                        switch (prev.0, item) {
                        case (.none, .none):
                            return (item, nil)
                        case let (.none, .some(c)):
                            return (item, .inserted(c))
                        case (.some, .none):
                            return (item, .deleted)
                        case let (.some(p), .some(c)):
                            return (item, p == c ? nil : .modified(c))
                        }
                    }
                }
                .compactMap { $0?.1 }
                .values
                .eraseToStream()
        }
        
        func linkTx(input: [Movie.ID: Set<Actor.ID>]) -> [Link.ID: Link] {
            input.reduce(into: [:]) { partialResult, item in
                for actorId in item.value {
                    let link = Link(id: .init(actorId: actorId, movieId: item.key))
                    partialResult[link.id] = link
                }
            }
        }
        
        return Storage(
            actors: .init(
                all: { actors.value },
                delete: { actors.value.removeValue(forKey: $0.id) },
                object: { actors.value[$0] },
                observeAll: { pipeline1(source: actors) },
                observeObject: { pipeline2(source: actors, id: $0) },
                upsert: { actors.value[$0.id] = $0 }
            ),
            movies: .init(
                all: { movies.value },
                delete: { movies.value.removeValue(forKey: $0.id) },
                object: { movies.value[$0] },
                observeAll: { pipeline1(source: movies) },
                observeObject: { pipeline2(source: movies, id: $0) },
                upsert: { movies.value[$0.id] = $0 }
            ),
            links: .init(
                all: { linkTx(input: links.value) },
                delete: { links.value[$0.id.movieId, default: []].remove($0.id.actorId) },
                object: { linkTx(input: links.value)[$0] },
                observeAll: { pipeline1(source: links.map(linkTx)) },
                observeObject: { pipeline2(source: links.map(linkTx), id: $0) },
                upsert: { links.value[$0.id.movieId, default: []].insert($0.id.actorId) }
            )
        )
    }
}

extension [Actor.ID: Actor] {
    static let mock: Self = [Actor.mock.id: .mock]
}

extension [Movie.ID: Movie] {
    static let mock: Self = [Movie.mock.id: .mock]
}

extension [Movie.ID: Set<Actor.ID>] {
    static let mock: Self = [Movie.mock.id: [Actor.mock.id]]
}

extension Storage: TestDependencyKey {
    static var previewValue: Storage = Self.defaultValue(
        actors: .mock,
        movies: .mock,
        links: .mock
    )
}

extension Storage: DependencyKey {
    static let liveValue: Storage = Self.defaultValue()
}

extension DependencyValues {
    var storage: Storage {
        get { self[Storage.self] }
        set { self[Storage.self] = newValue }
    }
}


