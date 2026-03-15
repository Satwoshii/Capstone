import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'models/user.dart';
import 'services/auth_repository.dart';
import 'services/rooms_repository.dart';

class AppState extends ChangeNotifier {
  final AuthRepository auth;
  final RoomsRepository roomsRepo;

  AppState({required this.auth, required this.roomsRepo});

  AppUser? _user;
  List<String> _labs = const [];

  AppUser? get user => _user;
  List<String> get labs => List.unmodifiable(_labs);

  Future<void> bootstrap() async {
    _labs = await roomsRepo.loadLabs();
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _user = await auth.signIn(email: email, password: password);
    notifyListeners();
  }

  Future<void> signOut() async {
    await auth.signOut();
    _user = null;
    notifyListeners();
  }

  bool isValidLab(String lab) => _labs.contains(lab);

  Future<void> addLab(String lab) async {
    final v = lab.trim();
    if (v.isEmpty) return;
    if (!_labs.contains(v)) {
      _labs = [..._labs, v]..sort();
      await roomsRepo.saveLabs(_labs);
      notifyListeners();
    }
  }

  Future<void> removeLab(String lab) async {
    if (_labs.contains(lab)) {
      _labs = _labs.where((e) => e != lab).toList();
      await roomsRepo.saveLabs(_labs);
      notifyListeners();
    }
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState appState, required super.child})
      : super(notifier: appState);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in widget tree');
    return scope!.notifier!;
  }

  @override
  bool updateShouldNotify(covariant InheritedNotifier<AppState> oldWidget) => true;
}
