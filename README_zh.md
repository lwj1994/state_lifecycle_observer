# Flutter State Observer

使用 Observer 模式解决状态复用问题的 Flutter 包。

## 特性

- **LifecycleObserver**: 用于创建可复用状态观察者的基类。
- **LifecycleObserverMixin**: 用于在 `State` 中管理观察者生命周期的 mixin。
- **常用观察者**:
  - `AnimControllerObserver`: 可复用的 `AnimationController` 逻辑。
  - `ScrollControllerObserver`: 管理 `ScrollController`。
  - `TabControllerObserver`: 管理 `TabController`。
  - `TextEditingControllerObserver`: 管理 `TextEditingController`。

## 用法

1. 创建一个 `StatefulWidget` 并混入 `LifecycleObserverMixin`。
2. 在 `initState` 中实例化观察者。它们会自动注册。
3. 在 `build` 方法中调用 `super.build(context)`。

```dart
class MyLogo extends StatefulWidget {
  final Duration speed;
  const MyLogo({super.key, required this.speed});

  @override
  State<MyLogo> createState() => _MyLogoState();
}

class _MyLogoState extends State<MyLogo> 
    with TickerProviderStateMixin, LifecycleObserverMixin<MyLogo> {
  
  late AnimControllerObserver _animObserver;
  late ScrollControllerObserver _scrollObserver;

  @override
  void initState() {
    super.initState();

    // 逻辑复用：将 'this' 作为第一个参数传递。
    // 观察者会自动注册到 mixin 中。
    _animObserver = AnimControllerObserver(
      this,
      duration: () => widget.speed,
    );

    _scrollObserver = ScrollControllerObserver(
      this,
      initialScrollOffset: 100.0,
    );

    _animObserver.target.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    // 通知观察者进行构建
    super.build(context);
    
    return SingleChildScrollView(
      controller: _scrollObserver.target,
      child: ScaleTransition(
        scale: _animObserver.target, 
        child: const FlutterLogo()
      ),
    );
  }
}
```

### 可用观察者

#### AnimControllerObserver
自动从 Widget 属性同步参数。支持所有 `AnimationController` 属性。
需要 `TickerProvider`（需混入 `TickerProviderStateMixin`）。

```dart
_anim = AnimControllerObserver(
  this,
  duration: () => widget.duration,
  reverseDuration: () => widget.reverseDuration,
  lowerBound: 0.0,
  upperBound: 1.0,
  debugLabel: 'MyAnim',
);
```

#### ScrollControllerObserver
简化 `ScrollController` 的创建和销毁。

```dart
_scroll = ScrollControllerObserver(
  this,
  initialScrollOffset: 0.0,
  keepScrollOffset: true,
);
```

#### TabControllerObserver
简化 `TabController` 的创建和销毁。
需要 `TickerProvider`。

```dart
_tab = TabControllerObserver(
  this,
  length: 3,
  initialIndex: 0,
);
```

#### TextEditingControllerObserver
简化 `TextEditingController` 的创建和销毁。

```dart
_text = TextEditingControllerObserver(
  this,
  text: '初始文本',
);
```

### 自定义观察者

你可以通过继承 `LifecycleObserver` 轻松创建自己的观察者。

示例：一个 `UserDataObserver`，它能够：
1. 在 `onInit` 中初始化数据获取。
2. 在 `onUpdate` 中当 `userId` 变化时重新获取数据。
3. 在 `onBuild` 中记录调试信息。

```dart
import 'package:flutter/material.dart';
import 'package:state_lifecycle_observer/state_lifecycle_observer.dart';

class Data {
  final String id;
  final String info;
  Data(this.id, this.info);
}

class UserDataObserver extends LifecycleObserver<ValueNotifier<Data?>> {
  // 获取 Widget 最新参数的机制
  final String Function() getUserId;
  
  // 用于追踪变化的内部状态
  late String _currentUserId;

  UserDataObserver(
    super.state, {
    required this.getUserId,
  });

  @override
  void onInit() {
    target = ValueNotifier(null);
    _currentUserId = getUserId();
    _fetchData(_currentUserId);
  }

  @override
  void onUpdate() {
    // 检查依赖 (userId) 是否发生变化
    final newUserId = getUserId();
    if (newUserId != _currentUserId) {
      debugPrint('UserId changed from $_currentUserId to $newUserId');
      _currentUserId = newUserId;
      _fetchData(_currentUserId);
    }
  }

  @override
  void onBuild(BuildContext context) {
    debugPrint('Building with user: $_currentUserId');
  }

  @override
  void onDispose() {
    target.dispose();
  }

  void _fetchData(String id) async {
    // 模拟网络请求
    await Future.delayed(const Duration(milliseconds: 500));
    if (_currentUserId == id) { // 避免竞态条件
      target.value = Data(id, 'Info for $id');
    }
  }
}
```

## 与 flutter_hooks 的比较

| 特性 | state_lifecycle_observer | flutter_hooks |
| :--- | :--- | :--- |
| **范式** | OOP (类) | 函数式 (Hooks) |
| **基类** | 标准 `StatefulWidget` | `HookWidget` |
| **生命周期** | 显式 (`onInit`, `onDispose`) | 隐式 (`useEffect`) |
| **学习曲线** | 低 (标准 Flutter) | 中 (Hooks 规则) |
| **黑魔法** | 低 (Mixin + List) | 高 (Element 逻辑) |
| **条件逻辑** | 随处支持 | 不允许在 `build` 中使用 |

### 为什么选择 state_lifecycle_observer?
- 你更喜欢面向对象编程。
- 你想坚持使用标准的 `StatefulWidget`。
- 你不喜欢 "Hooks 规则"（例如，不能使用条件 Hooks）。
- 你希望对初始化和销毁有显式的控制。
