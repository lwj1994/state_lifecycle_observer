# Flutter 状态复用完全指南

## 问题背景：状态复用为什么重要

在 Flutter 中，`StatefulWidget` 提供了 `initState`、`didUpdateWidget`、`dispose` 和 `build` 等生命周期方法。虽然功能强大，但管理复杂的状态逻辑会导致大量重复的样板代码：

```dart
class _MyWidgetState extends State<MyWidget> with TickerProviderStateMixin {
  late AnimationController _controller;
  late TextEditingController _textController;
  late ScrollController _scrollController;
  StreamSubscription? _subscription;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _textController = TextEditingController(text: widget.initialText);
    _scrollController = ScrollController();
    _subscription = widget.stream.listen(_onData);
  }
  
  @override
  void didUpdateWidget(MyWidget old) {
    super.didUpdateWidget(old);
    if (old.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    // 更多同步逻辑...
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _textController.dispose();
    _scrollController.dispose();
    _subscription?.cancel();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

这种模式存在几个问题：
1. **代码重复** - 每个 Widget 都需要类似的初始化/销毁配对
2. **容易出错** - 很容易忘记清理资源
3. **无法复用** - 逻辑和特定 Widget 耦合
4. **难以测试** - 状态逻辑和 UI 混在一起

## 方案一：React Hooks (flutter_hooks)

`flutter_hooks` 包将 React 的 Hooks 模式带到了 Flutter：

```dart
class BookPage extends HookWidget {
  final int bookId;
  
  @override
  Widget build(BuildContext context) {
    final controller = useAnimationController(duration: Duration(seconds: 1));
    final snapshot = useFuture(fetchBook(bookId));
    
    return Text('${snapshot.data}');
  }
}
```

### Hooks 的优势
- ✅ 简洁且声明式
- ✅ 自动清理资源
- ✅ 可组合（自定义 hooks）
- ✅ 对 React 开发者友好

### Hooks 的局限
- ❌ 需要 `HookWidget` 基类
- ❌ 执行顺序很重要（不能有条件判断/循环）
- ❌ "黑魔法" - 依赖 Element 内部机制
- ❌ Flutter 开发者需要学习成本

## 方案二：LifecycleObserver 模式

`state_lifecycle_observer` 包采用面向对象的方式，灵感来自 Android 的 LifecycleObserver：

```dart
class _BookPageState extends State<BookPage> with LifecycleOwnerMixin {
  late AnimControllerObserver animObserver;
  late FutureObserver<Book> fetchObserver;
  
  @override
  void initState() {
    super.initState();
    animObserver = AnimControllerObserver(this, duration: () => Duration(seconds: 1));
    fetchObserver = FutureObserver(this, future: () => fetchBook(widget.bookId));
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Text('${fetchObserver.target.data}');
  }
}
```

### Observer 的优势
- ✅ 标准 `StatefulWidget` - 无需特殊基类
- ✅ 无执行顺序限制
- ✅ dispose 时自动清理
- ✅ `key` 参数支持值变化时自动重建
- ✅ 可组合（观察者可以创建嵌套观察者）
- ✅ 低魔法 - 只是 mixin + 列表管理

### Observer 的局限
- ❌ 比 hooks 更冗长
- ❌ 需要显式调用 `super.build(context)`

## 特性对比

| 特性 | flutter_hooks | state_lifecycle_observer |
|:--------|:-------------|:------------------------|
| **范式** | 函数式 | 面向对象 |
| **基类** | 必须使用 `HookWidget` | 标准 `StatefulWidget` |
| **生命周期** | 隐式 (`useEffect`) | 显式 (`buildTarget`, `onDispose`) |
| **学习曲线** | 中等（Hooks 规则） | 低（标准 Flutter） |
| **执行顺序** | 严格（不能有条件判断） | 灵活 |
| **可组合性** | ✅ 自定义 hooks | ✅ 嵌套 observers |
| **自动清理** | ✅ | ✅ |
| **基于 Key 重建** | ✅ `useMemoized(key:)` | ✅ `key` 参数 |
| **运行时值变化** | ✅ 内置支持 | ✅ 函数构建器模式 |

## 处理运行时值变化

一个常见的挑战是响应 Widget 属性的变化。两种方案都能优雅地处理：

### Hooks 方式
```dart
class BookPage extends HookWidget {
  final int bookId;
  
  @override
  Widget build(BuildContext context) {
    // bookId 变化时自动重新获取
    final snapshot = useFuture(
      useMemoized(() => fetchBook(bookId), [bookId]),
    );
    return Text('${snapshot.data}');
  }
}
```

### Observer 方式
```dart
class FetchObserver extends LifecycleObserver<AsyncSnapshot<Response>> {
  final int Function() bookId;
  
  FetchObserver(super.state, {required this.bookId}) 
      : super(key: bookId);  // 用于变化检测的 Key
  
  @override
  AsyncSnapshot<Response> buildTarget() {
    http.get(Uri.parse('https://api/books/${bookId()}')).then((response) {
      target = AsyncSnapshot.withData(ConnectionState.done, response);
      safeSetState(() {});
    });
    return const AsyncSnapshot.waiting();
  }
}

// 使用方式
class _BookPageState extends State<BookPage> with LifecycleOwnerMixin {
  FetchObserver? fetchObserver;
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    fetchObserver ??= FetchObserver(this, bookId: () => widget.bookId);
    return Text('${fetchObserver!.target.data}');
  }
}
```

当 `widget.bookId` 变化时：
1. `build()` 触发 `onBuild()`
2. `onBuild()` 检测到 `key()` 值变化
3. `onDisposeTarget()` 清理旧资源
4. `buildTarget()` 创建新资源

## 可组合性：从简单部件构建复杂状态

两种方案都支持可组合性 - 从更简单、可复用的部件构建复杂的状态逻辑。

### Hooks：自定义 Hooks
```dart
AsyncSnapshot<User> useUser(int userId) {
  final snapshot = useFuture(
    useMemoized(() => fetchUser(userId), [userId]),
  );
  return snapshot;
}

// 使用
class UserPage extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final user = useUser(123);
    return Text('${user.data?.name}');
  }
}
```

### Observer：嵌套观察者
```dart
class UserProfileObserver extends LifecycleObserver<void> {
  late final TextEditingControllerObserver nameController;
  late final FutureObserver<UserData> dataFetcher;

  UserProfileObserver(super.state, {required int Function() userId});

  @override
  void onInitState() {
    super.onInitState();
    // 子观察者通过 Zone 机制自动注册
    nameController = TextEditingControllerObserver(state);
    dataFetcher = FutureObserver(state, future: () => fetchUserData(userId()));
  }

  @override
  void buildTarget() {}
}

// 使用
class _MyPageState extends State<MyPage> with LifecycleOwnerMixin {
  late final profileObserver = UserProfileObserver(this, userId: () => widget.userId);
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        TextField(controller: profileObserver.nameController.target),
        Text('${profileObserver.dataFetcher.target.data}'),
      ],
    );
  }
}
```

## 如何选择？

**选择 flutter_hooks 如果：**
- 你来自 React 背景
- 你偏好函数式编程风格
- 你想要最简洁的语法
- 你能接受 "Hooks 规则"

**选择 state_lifecycle_observer 如果：**
- 你偏好 OOP 和标准 Flutter 模式
- 你需要条件性地创建观察者
- 你想要渐进式的迁移路径
- 你更看重显式而非隐式的行为
- 你想避免第三方 Element 逻辑

## 总结

`flutter_hooks` 和 `state_lifecycle_observer` 都解决了同一个根本问题：让有状态逻辑可复用、可组合。它们代表了不同的哲学：

- **Hooks**：函数式、简洁、魔法多
- **Observers**：面向对象、显式、标准 Flutter

没有哪个是绝对"更好"的 - 根据你的团队偏好和现有代码库来选择。重要的是使用*某种*状态复用模式，而不是在各个 Widget 之间复制粘贴样板代码。

---

## 资源

- [flutter_hooks](https://pub.dev/packages/flutter_hooks)
- [state_lifecycle_observer](https://pub.dev/packages/state_lifecycle_observer)
- [Android LifecycleObserver](https://developer.android.com/reference/androidx/lifecycle/LifecycleObserver)
