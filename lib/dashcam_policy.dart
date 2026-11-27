const maxLibraryBytes = 1024 * 1024 * 1024;

class ClipRecord {
  const ClipRecord(this.name, this.bytes, this.locked, this.created);
  final String name;
  final int bytes;
  final bool locked;
  final int created;
}

// Returns the oldest unlocked clips required to admit a new clip.
// Null means that capacity cannot be satisfied without deleting a protected clip.
List<String>? planClipEviction(List<ClipRecord> clips, int incomingBytes, {
  required bool loop, int byteLimit = maxLibraryBytes, int countLimit = 20,
}) {
  if (incomingBytes <= 0 || incomingBytes > byteLimit || countLimit < 1 ||
      clips.any((clip) => clip.bytes < 0)) {
    return null;
  }
  var bytes = clips.fold<int>(incomingBytes, (sum, clip) => sum + clip.bytes);
  var count = clips.length + 1;
  final deletions = <String>[];
  if (bytes <= byteLimit && count <= countLimit) return deletions;
  if (!loop) return null;
  final candidates = clips.where((clip) => !clip.locked).toList()
    ..sort((a, b) {
      final order = a.created.compareTo(b.created);
      return order == 0 ? a.name.compareTo(b.name) : order;
    });
  for (final clip in candidates) {
    deletions.add(clip.name);
    bytes -= clip.bytes;
    count--;
    if (bytes <= byteLimit && count <= countLimit) return deletions;
  }
  return null;
}
