class Message {
  const Message({required this.text, required this.own, required this.time});
  final String text;
  final bool own;

  /// "HH:mm"
  final String time;
}

/// A conversation with one matched person.
class Thread {
  const Thread({required this.id, required this.personId, this.unread = 0, this.messages = const []});

  final String id;
  final String personId;
  final int unread;
  final List<Message> messages;

  Message? get last => messages.isEmpty ? null : messages.last;

  Thread copyWith({int? unread, List<Message>? messages}) =>
      Thread(id: id, personId: personId, unread: unread ?? this.unread, messages: messages ?? this.messages);
}
