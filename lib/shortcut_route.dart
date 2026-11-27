enum ShortcutRoute { map, audio, assistant }

ShortcutRoute? parseShortcutRoute(Object? value) => switch (value) {
  'map' => ShortcutRoute.map,
  'audio' => ShortcutRoute.audio,
  'assistant' => ShortcutRoute.assistant,
  _ => null,
};
