abstract class RoomsRepository {
  Future<List<String>> loadLabs();
  Future<void> saveLabs(List<String> labs);
}
