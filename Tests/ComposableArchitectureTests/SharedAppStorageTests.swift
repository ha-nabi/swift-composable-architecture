import ComposableArchitecture
import XCTest

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
@MainActor
final class SharedAppStorageTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
  }

  func testSubscription() async throws {
    let store = TestStore(initialState: Feature.State()) {
      Feature()
    }

    await store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    @Dependency(\.userDefaults) var userDefaults
    userDefaults.setValue(Data("42".utf8), forKey: "count")
    await Task.yield()
    XCTAssertEqual(store.state.count , 42)
  }

  func testSiblings() async {
    let store = TestStore(initialState: ParentFeature.State()) {
      ParentFeature()
    }

    await store.send(.child1(.incrementButtonTapped)) {
      $0.child1.count = 1
      XCTAssertEqual($0.child2.count, 1)
    }
    await store.send(.child2(.incrementButtonTapped)) {
      $0.child2.count = 2
      XCTAssertEqual($0.child1.count, 2)
    }
    await store.send(.child1(.incrementButtonTapped)) {
      $0.child2.count = 3
      XCTAssertEqual($0.child1.count, 3)
    }
    await store.send(.child2(.incrementButtonTapped)) {
      $0.child1.count = 4
      XCTAssertEqual($0.child2.count, 4)
    }
  }

  func testSiblings_Failure() async {
    let store = TestStore(initialState: ParentFeature.State()) {
      ParentFeature()
    }

    XCTExpectFailure {
      $0.compactDescription == """
        State was not expected to change, but a change occurred: …

              ParentFeature.State(
                _child1: Feature.State(
            −     _count: 0
            +     _count: 1
                ),
                _child2: Feature.State(
            −     _count: 0
            +     _count: 1
                )
              )

        (Expected: −, Actual: +)
        """
    }
    await store.send(.child1(.incrementButtonTapped))
  }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
@Reducer
private struct ParentFeature {
  @ObservableState
  struct State: Equatable {
    var child1 = Feature.State()
    var child2 = Feature.State()
  }
  enum Action {
    case child1(Feature.Action)
    case child2(Feature.Action)
  }
  var body: some ReducerOf<Self> {
    Scope(state: \.child1, action: \.child1) {
      Feature()
    }
    Scope(state: \.child2, action: \.child2) {
      Feature()
    }
  }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
@Reducer
private struct Feature {
  @ObservableState
  struct State: Equatable {
    @Shared(.appStorage("count")) var count = 0
  }
  enum Action {
    case incrementButtonTapped
  }
  var body: some ReducerOf<Self> {
    Reduce { state, action in

      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
      }
    }
  }
}