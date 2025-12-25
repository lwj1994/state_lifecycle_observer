## 0.0.1

* Initial release.
* Added `LifecycleObserver` base class and `LifecycleObserverMixin`.
* Included common observers:
  * `AnimControllerObserver` (supports full `AnimationController` params)
  * `ScrollControllerObserver`
  * `TabControllerObserver`
  * `TextEditingControllerObserver`
* Implemented automatic lifecycle management (`onInit`, `onUpdate`, `onDispose`).
* Seamless integration via `super.build(context)`.
