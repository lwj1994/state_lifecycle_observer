## 0.1.0
* **Breaking**: Move `key` change detection from `onDidUpdateWidget` to `onBuild` for better support of late-created observers.

## 0.0.9
* Implement Observer composability - observers can create nested observers within any lifecycle method (`onInitState`, `onDidUpdateWidget`, `onBuild`).

```dart
class ParentObserver extends LifecycleObserver<void> {
  ChildObserver? child;
  
  ParentObserver(super.state);
  
  @override
  void onInitState() {
    super.onInitState();
    // Create nested observers anywhere in lifecycle methods
    child = ChildObserver(state);
  }
}
```

## 0.0.8
* Add project logo and update README documentation.
* Add CI workflow with GitHub Actions and Codecov integration.
* Achieve 100% test coverage.

## 0.0.7
* Update documentation with `addLifecycleCallback` usage examples.
* Add language switch links between English and Chinese README.
* Simplify code examples to use `late final` for observer initialization.
## 0.0.6
* Replace `assert` with `StateError` for missing mixin, correct `addLifecyccleCallback` typo.

## 0.0.5
* Add `addLifecyccleCallback`
```dart
  void initState() {
    super.initState();
    addLifecycleCallback(
      onInitState: () {
        widget.log.onInitState++;
      },
      onDidUpdateWidget: () {
        widget.log.onDidUpdateWidget++;
      },
      onDispose: () {
        widget.log.onDispose++;
      },
      onBuild: (context) {
        widget.log.onBuild++;
      },
    );
  }
```

## 0.0.4

* **Breaking Change**: Renamed `LifecycleObserverMixin` to `LifecycleOwnerMixin` to better reflect its role.
* **Breaking Change**: `LifecycleObserver` initialization is now deferred. `target` is available only after `onInitState` is called (which happens automatically). Accessing it prematurely throws `LateInitializationError`.
* **Enhancement**: Added automatic synchronization for "late" observers. Observers added after `initState` are now immediately initialized to catch up with the lifecycle.
* **Refactor**: Introduced `LifecycleState` enum (`created`, `initialized`, `disposed`) to track component state.
* **Fix**: Removed `StateWithObservers` interface in favor of checking against `LifecycleOwnerMixin` directly.

## 0.0.3

* **Enhancement**: Introduced `safeSetState` in `LifecycleObserver` to handle state updates safely across different scheduler phases.
* **Fix**: `FutureObserver` and `StreamObserver` now use `safeSetState` to prevent errors when updates are triggered during build, layout, or paint phases.
* **Docs**: Reorganized README to clearly categorize built-in observers (Base, Widget, Anim) and added clarification on `key` usage.

## 0.0.2

* **Breaking Change**: Renamed `onUpdate` to `onDidUpdateWidget` to better align with Flutter's lifecycle naming.
* **Breaking Change**: Removed `onInit`. Initialization logic should be moved to the constructor or `buildTarget`.
* **Enhancement**: Added safety assertion to ensure `state` mixes in `LifecycleObserverMixin`.
* **Docs**: Updated README with `key` usage explanation and new API examples. 

## 0.0.1

* Initial release.
* Added `LifecycleObserver` base class and `LifecycleOwnerMixin`.
* Included common observers:
  * `AnimControllerObserver` (supports full `AnimationController` params)
  * `ScrollControllerObserver`
  * `TabControllerObserver`
  * `TextEditingControllerObserver`
* Implemented automatic lifecycle management (`onInit`, `onUpdate`, `onDispose`).
* Seamless integration via `super.build(context)`.
