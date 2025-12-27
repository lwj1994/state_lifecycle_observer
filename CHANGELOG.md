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
