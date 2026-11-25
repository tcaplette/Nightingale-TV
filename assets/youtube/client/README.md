# YouTube's Google client

The app signs people in to YouTube with the Google client file in this folder:

    assets/youtube/client/nightingale-tv-youtube.json

It is the JSON file Google Cloud downloads for an OAuth client of the type
**TVs and Limited Input devices**, in a project with the YouTube Data API v3
turned on. Save it here unchanged.

The file is git-ignored and never committed. Nightingale TV's own file is not
part of the source: if you fork or clone the project, create your own client
and save its file here. Every build then signs in through Google with it
(`flutter run`, VS Code or the `tool/` scripts). Without the file, the YouTube
button says the build has no YouTube client.
