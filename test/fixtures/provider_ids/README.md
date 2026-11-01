Provider ids in the scan's listing requests (multi-server task 1.1, 2026-10-31).

- `jellyfin_*.json`: the test server, `Fields=ProviderIds` added to the
  listing. Without that field Jellyfin sends no `ProviderIds` at all.
  Episodes carry `Tvdb` (some `Imdb`); movies and series `Imdb`, `Tmdb`, `Tvdb`.
- Emby (Docker, generated library) answers the same way: `ProviderIds` only
  with `Fields=ProviderIds`, and `{}` for the generated files (no metadata
  agent reaches the internet).
- `plex_episodes_none_agent.json`: Docker Plex with `includeGuids=1`. The
  generated libraries use the "none" agent, so items have only their own
  `guid` (`tv.plex.agents.none://…`) and no `Guid` array. Libraries on
  Plex's own agents list `Guid: [{"id": "imdb://…"}, {"id": "tmdb://…"},
  {"id": "tvdb://…"}]` under the same parameter.
