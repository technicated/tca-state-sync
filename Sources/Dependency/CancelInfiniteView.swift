//
//  CancelInfiniteView.swift
//  
//
//  Created by Andrea Tomarelli on 15/09/23.
//

import ComposableArchitecture
import SwiftUI

struct CancelInfiniteFeature: Reducer {
    struct State {
        var counter: Int = 0
    }
    
    enum Action {
        case buttonTapped
        case task
        case taskEmitted
        case valueReceived(Int)
    }
    
    @Dependency(\.continuousClock)
    var clock
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .buttonTapped:
                state.counter += 1
 
                return self.complexEffect(counter: state.counter)
                
            case .task:
                return .run { send in
                    while true {
                        try await clock.sleep(for: .seconds(.random(in: 1 ... 5)))
                        await send(.taskEmitted)
                    }
                }
                
            case .taskEmitted:
                return complexEffect(counter: .random(in: -10 ... -1))
            
            case let .valueReceived(value):
                return .run { _ in
                    print(value)
                }
            }
        }
    }
    
    private func complexEffect(counter: Int) -> Effect<Action> {
        .run { send in
            for await _ in clock.timer(interval: .seconds(1)) {
                await send(.valueReceived(counter))
            }
        }
        .cancellable(id: "gg", cancelInFlight: true)
    }
}

enum Test<A> {
    case a([A])
}

struct CancelInfiniteView: View {
    let store: StoreOf<CancelInfiniteFeature>

    var body: some View {
        VStack {
            Text("\(String(describing: (/Test<Int>.a).embed([1, 12])))")
            
            Button("Hello, World!") {
                store.send(.buttonTapped)
            }
            //.task { await store.send(.task).finish() }
        }
    }
}

struct CancelInfiniteView_Previews: PreviewProvider {
    static var previews: some View {
        CancelInfiniteView(
            store: Store(initialState: CancelInfiniteFeature.State()) {
                CancelInfiniteFeature()
                    ._printChanges()
            }
        )
    }
}
