//
//  Models.swift
//  TCA-Navigation
//
//  Created by Andrea Tomarelli on 02/09/23.
//

import Foundation
import Tagged

struct Actor: Equatable, Identifiable {
    let id: Tagged<Actor, UUID>
    var name: String
}

struct Movie: Equatable, Identifiable {
    let id: Tagged<Movie, UUID>
    var title: String
}

