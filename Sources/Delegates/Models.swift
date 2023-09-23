//
//  File.swift
//  
//
//  Created by Andrea Tomarelli on 11/09/23.
//

import ComposableArchitecture
import Foundation
import Tagged

public struct Actor: Equatable, Identifiable {
    public let id: Tagged<Actor, UUID>
    var name: String
    
    public init(id: Tagged<Actor, UUID>, name: String) {
        self.id = id
        self.name = name
    }
}

extension Actor {
    static let mock = Actor(id: .init(UUID()), name: "Mark Hamill")
}

extension IdentifiedArrayOf<Actor> {
    static let mock: Self = [
        Actor(id: .init(UUID()), name: "Carrie Fisher"),
        Actor(id: .init(UUID()), name: "Harrison Ford"),
        Actor(id: .init(UUID()), name: "Mark Hamill")
    ]
}

public struct Movie: Equatable, Identifiable {
    public let id: Tagged<Movie, UUID>
    var title: String
}

extension Movie {
    static let mock = Movie(id: .init(UUID()), title: "Star Wars IV: A New Hope")
}

extension IdentifiedArrayOf<Movie> {
    static let mock: Self = [
        Movie(id: .init(UUID()), title: "Star Wars IV: A New Hope"),
        Movie(id: .init(UUID()), title: "Star Wars V: The Empire Strikes Back"),
        Movie(id: .init(UUID()), title: "Star Wars VI: The Return Of The Jedi")
    ]
}
