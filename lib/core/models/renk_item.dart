class RenkItem {
  final String id;
  final String ad;

  RenkItem({required this.id, required this.ad});

  factory RenkItem.fromDoc(String id, Map<String, dynamic> m) {
    return RenkItem(
      id: id,
      ad: (m['ad'] as String?)?.trim() ?? '',
    );
  }
}
