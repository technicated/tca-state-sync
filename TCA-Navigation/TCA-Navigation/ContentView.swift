//
//  ContentView.swift
//  TCA-Navigation
//
//  Created by Andrea Tomarelli on 02/09/23.
//

import ComposableArchitecture
import SwiftUI

struct AppFeature: Reducer {
    struct State: Equatable {
        var counter: Int = 0
        var isTimerOn: Bool = false
    }

    enum Action {
        case decrementButtonTapped
        case incrementButtonTapped
        case toggleTimerButtonTapped

        case timerTicked
    }
    
    private enum CancelId {
        case timer
    }
    
    @Dependency(\.continuousClock)
    var clock
    
    var body: some ReducerOf<Self> {
        Reduce { (state, action) in
            switch action {
            case .decrementButtonTapped:
                state.counter -= 1
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.incrementButtonTapped)
                }

            case .incrementButtonTapped:
                state.counter += 1
                return .none
            
            case .toggleTimerButtonTapped:
                state.isTimerOn.toggle()
                if (state.isTimerOn) {
                    return .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.timerTicked)
                        }
                    }
                    .cancellable(id: CancelId.timer)
                } else {
                    return .cancel(id: CancelId.timer)
                }
                
            case .timerTicked:
                state.counter += 1
                return .none
            }
        }
    }
}

struct _ContentView: View {
    let store = StoreOf<AppFeature>(initialState: .init()) {
        AppFeature()
    }

    var body: some View {
        /*VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
        }
        .padding()*/
        
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 20) {
                HStack(spacing: 20) {
                    Button("-") {
                        viewStore.send(.decrementButtonTapped)
                    }
                    
                    Text("\(viewStore.counter)")
                    
                    Button("+") {
                        viewStore.send(.incrementButtonTapped)
                    }
                }
                
                Button(viewStore.isTimerOn ? "Stop Timer" : "Start Timer") {
                    viewStore.send(.toggleTimerButtonTapped)
                }
            }
        }
    }
}

struct Value {
    var get: () -> Int
    var set: (Int) -> Void
    var stream: () -> AsyncStream<Int>
}

extension DependencyValues {
    var value: Value {
    get { self[Value.self] }
    set { self[Value.self] = newValue }
  }
}

extension Value: DependencyKey {
    static let liveValue = {
        var continuations: [AsyncStream<Int>.Continuation] = []
        
        var value = 0 {
            didSet {
                print("did set", value)
                
                for cont in continuations {
                    cont.yield(value)
                }
            }
        }
        
        return Value(get: { value }, set: { value = $0 }) {
            AsyncStream { continuation in
                continuations.append(continuation)
                continuation.yield(value)
            }
        }
    }()
}

struct ParentFeature: Reducer {
    struct State: Equatable {
        var actors: [Actor] = [.init(id: .init(UUID()), name: "Boh 1"), .init(id: .init(UUID()), name: "Boh 2")]
        var path: StackState<Path.State> = .init()
        let useless = 0
    }
    
    enum Action {
        case path(StackAction<Path.State, Path.Action>)
        case goToActorTapped
    }
    
    struct Path: Reducer {
        enum State: Equatable {
            case actor(ActorDetailFeature.State)
        }
        
        enum Action {
            case actor(ActorDetailFeature.Action)
        }
        
        var body: some ReducerOf<Self> {
            Scope(state: /State.actor, action: /Action.actor) {
                ActorDetailFeature()
            }
        }
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .path(.element(id, action: .actor(.delegate(.actorNameChanged(name))))):
                guard case let .actor(modified) = state.path[id: id] else { return .none }
                
                for id in state.path.ids {
                    let child = state.path[id: id]
                    
                    switch child {
                    case var .actor(a):
                        if a.actor.id == modified.actor.id {
                            a.actor.name = name
                        }
                        state.path[id: id] = .actor(a)

                    case .none:
                        break
                    }
                }
                return .none
                
            case .path(.element(id: _, action: .actor(.delegate(.goToActor)))):
                //state.path.append(.actor(Bool.random() ? .mock : .init(actor: .init(id: .init(UUID()), name: "Boh"), movies: [])))
                state.path.append(.actor(.init(actor: state.actors.randomElement()!, movies: [])))
                return .none

            case .path:
                return .none
                
            case .goToActorTapped:
                //state.path.append(.actor(.mock))
                state.path.append(.actor(.init(actor: state.actors.randomElement()!, movies: [])))
                return .none
            }
        }
        .forEach(\.path, action: /Action.path) {
            Path()
        }
    }
}

struct ContentView: View {
    let store: StoreOf<ParentFeature>

    var body: some View {
        NavigationStackStore(
             self.store.scope(state: \.path, action: { .path($0) })
        ) {
            WithViewStore(store, observe: \.useless) { viewStore in
                Button("Go to Actor") {
                    viewStore.send(.goToActorTapped)
                }
            }
        } destination: { state in
            switch state {
            case .actor:
                CaseLet(
                    /ParentFeature.Path.State.actor,
                    action: ParentFeature.Path.Action.actor,
                    then: ActorDetailView.init(store:)
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(
            store: .init(initialState: .init()) {
                ParentFeature()
            }
        )
    }
}
