//
//  Models.swift
//  
//
//  Created by Andrea Tomarelli on 12/09/23.
//

import Foundation
import Tagged

struct Actor: Equatable, Identifiable {
    let id: Tagged<Actor, UUID>
    var name: String
}

extension Actor {
    static let mock = Actor(
        id: .init(),
        name: "Andrea"
    )
}

struct Movie: Equatable, Identifiable {
    let id: Tagged<Movie, UUID>
    var title: String
}

extension Movie {
    static let mock = Movie(
        id: .init(),
        title: "Andrea's First Movie"
    )
}

struct Link: Equatable, Hashable, Identifiable {
    struct ID: Hashable {
        let actorId: Actor.ID
        let movieId: Movie.ID
    }
    
    let id: ID
}
