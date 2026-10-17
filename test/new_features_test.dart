import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:melodyflow/models/song.dart';
import 'package:melodyflow/providers/music_provider.dart';
import 'package:melodyflow/services/storage_service.dart';

Song _song(String id, {String title = 'T', int durationMs = 1000}) => Song(
      id: id,
      title: title,
      artist: 'A',
      album: 'B',
      duration: Duration(milliseconds: durationMs),
      uri: '/music/$id.mp3',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('最近播放存储', () {
    test('保存并读取最近播放列表，顺序保持', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = StorageService();
      await storage.init();

      final songs = [_song('1'), _song('2'), _song('3')];
      await storage.saveRecentSongs(songs);

      final loaded = storage.getRecentSongs();
      expect(loaded.length, 3);
      expect(loaded.map((s) => s.id).toList(), ['1', '2', '3']);
      expect(loaded.first.title, 'T');
    });

    test('损坏数据被跳过而不崩溃', () async {
      SharedPreferences.setMockInitialValues({
        'recent_songs': ['not-json', '{"id":"9","title":"X"}'],
      });
      final storage = StorageService();
      await storage.init();
      final loaded = storage.getRecentSongs();
      expect(loaded.length, 1);
      expect(loaded.first.id, '9');
    });
  });

  group('SongSortMode', () {
    test('枚举包含全部排序方式', () {
      expect(SongSortMode.values.length, 4);
      expect(SongSortMode.values, contains(SongSortMode.title));
      expect(SongSortMode.values, contains(SongSortMode.artist));
      expect(SongSortMode.values, contains(SongSortMode.duration));
      expect(SongSortMode.values, contains(SongSortMode.recentAdded));
    });
  });
}
