import 'dart:collection';

/// Generates shortest-unique-prefix hint labels in qutebrowser style.
///
/// Pure Dart — no Flutter dependencies.
class HintLabelGenerator {
  /// The character set used to build labels. Defaults to the home row.
  final String chars;

  const HintLabelGenerator({this.chars = 'asdfghjkl'});

  /// Returns [count] unique labels, as short as possible, with no label
  /// being a prefix of another label.
  ///
  /// Characters at the front of [chars] are preferred — they appear as
  /// single-character labels before later characters are expanded into
  /// multi-character prefixes.
  ///
  /// Algorithm (trie-leaf expansion):
  ///   Start with every single character as a candidate in a queue.
  ///   Read labels from the front (home-row preference).
  ///   Whenever remaining candidates < needed labels, expand the LAST
  ///   candidate into [chars.length] children — the "least preferred" label
  ///   grows first, keeping 'a', 's', … as short labels as long as possible.
  List<String> generate(int count) {
    if (count <= 0) return const [];

    // Deque of candidate trie leaves, initially all single characters.
    // We read from the front (most preferred) and expand from the back.
    final queue = Queue<String>()..addAll(chars.split(''));

    final labels = <String>[];

    while (labels.length < count) {
      // If we don't have enough candidates left, expand the last one.
      // Each expansion removes 1 leaf and adds chars.length children,
      // netting +chars.length-1 candidates.
      while (labels.length + queue.length < count) {
        final last = queue.removeLast();
        // Add children in forward chars order so they are consumed from the
        // front in home-row preference order. For future back-expansions,
        // the last child (chars[last]) will be expanded first.
        for (final c in chars.split('')) {
          queue.addLast(last + c);
        }
      }
      labels.add(queue.removeFirst());
    }

    return labels;
  }
}
