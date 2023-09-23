# tca-state-sync

This repository contains sample code for a complex scenario using
[Swift TCA](https://github.com/pointfreeco/swift-composable-architecture) (The
Composable Architecture) by Point-Free. This is related to a
[discussion](https://github.com/pointfreeco/swift-composable-architecture/discussions/2444)
I started on the TCA repo.

A `RootView` holds a `TabView` with two tabs, `ActorsList` and `MoviesList`.
From each list you can navigate, respectively, to the `ActorDetail` or to the
`MovieDetail`. These detail screens show the name of the Actor and the Movies
he/she is starring in or the title of the Movie and a list of the Actors
starring in it. You can continue to drill down to Actor -> Movie -> Actor etc.
from every detail screen.

The complexity is given from the fact that the entire application has to stay in
sync, i.e. every modification done to the Actor name or the Movie title from any
screen should immediately be reflected in every other screen, and this also
holds for the starring / starring in relation.

The suggested solution was to create a `Storage` dependency with "on change"
endpoints, to which all screens listen to stay up-to-date. The implemented
solution is in the "Dependency" target; the "Delegates" target was an older
approach based on Delegate Actions (another TCA approach to connect different
screens, applicable in other scenarios like direct parent-child communication).
My implementation is not the best possible approach, since the data is
synchronised in multiple steps and not all at once as proven by the provided
test, but it works as a proof of concept.

The solution also uses a `Storage` Reducer inside the lists and details feature
Reducers to encapsulate and implement all the sync logic. The shape of the
`Storage` dependency was loosely inspired by the API of
[Realm](https://www.mongodb.com/docs/realm/sdk/swift/quick-start/#watch-for-changes).





