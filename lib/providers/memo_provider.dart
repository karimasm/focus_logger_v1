import 'package:flutter/foundation.dart';
import '../data/data.dart';
import '../models/models.dart';
import '../services/sync_service.dart';
import '../services/user_service.dart';

/// Provider for managing in-context memos during activities
class MemoProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  
  List<MemoEntry> _currentActivityMemos = [];
  List<MemoEntry> _allMemos = [];
  String _searchQuery = '';
  bool _isLoading = false;
  
  List<MemoEntry> get currentActivityMemos => _currentActivityMemos;
  List<MemoEntry> get allMemos => _allMemos;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  
  /// Filtered memos based on search query
  List<MemoEntry> get filteredMemos {
    if (_searchQuery.isEmpty) return _allMemos;
    final query = _searchQuery.toLowerCase();
    return _allMemos.where((m) => 
      m.text.toLowerCase().contains(query)
    ).toList();
  }

  /// Load memos for an activity
  Future<void> loadMemosForActivity(String activityId) async {
    _currentActivityMemos = await dataRepository.getMemosForActivity(activityId);
    notifyListeners();
  }
  
  /// Load all memos for current user (Memo Tab)
  Future<void> loadAllMemos() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _allMemos = await dataRepository.getAllMemos();
    } catch (e) {
      debugPrint('[MEMO] Error loading all memos: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Search memos by text
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }
  
  /// Clear search
  void clearSearch() {
    _searchQuery = '';
    notifyListeners();
  }

  /// Add a new memo to the current running activity
  Future<void> addMemo({
    required String activityId,
    required String text,
    MemoSource source = MemoSource.manual,
  }) async {
    final memo = MemoEntry(
      activityId: activityId,
      timestamp: DateTime.now().toUtc(),  // FIX: Use UTC
      text: text,
      source: source,
      userId: UserService().currentUserId,
    );
    
    await dataRepository.insertMemoEntry(memo);
    _currentActivityMemos.add(memo);
    _allMemos.insert(0, memo);
    notifyListeners();
    
    await _syncService.triggerSync(SyncEvent.memoAdded);
  }

  /// Delete a memo
  Future<void> deleteMemo(String memoId) async {
    await dataRepository.deleteMemoEntry(memoId);
    _currentActivityMemos.removeWhere((m) => m.id == memoId);
    _allMemos.removeWhere((m) => m.id == memoId);
    notifyListeners();
  }

  /// Get memos for a specific activity
  Future<List<MemoEntry>> getMemosForActivity(String activityId) async {
    return await dataRepository.getMemosForActivity(activityId);
  }

  /// Clear current activity memos
  void clearCurrentMemos() {
    _currentActivityMemos = [];
    notifyListeners();
  }
}
