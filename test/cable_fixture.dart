import 'lineup_fixture.dart';

/// [n] episodes of one season.
List<(int?, int?)> _episodes(int n) => [for (var e = 1; e <= n; e++) (1, e)];

/// The test server's library as the 2026-11-03 diagnostic found it
/// (cable-lineup): 14 named shows and unnamed episodes, with the genres the
/// server lists in its order, and its 38 movies.
FixtureLibrary testServerLibrary() => FixtureLibrary(
      items: [
        for (final (id, name, year, genres, count) in _shows)
          FixtureItem(id, name, year: year, genres: genres, logo: true, episodes: _episodes(count)),
      ],
      unnamed: 100,
      namedMovies: _movies,
    );

const _shows = <(String, String, int, List<String>, int)>[
  ('30rock', '30 Rock', 2006, ['Comedy'], 135),
  ('archer', 'Archer', 2009, ['Action', 'Adventure', 'Animation', 'Comedy', 'Fantasy'], 49),
  ('calif', 'Californication', 2007, ['Drama', 'Comedy'], 72),
  ('eastbound', 'Eastbound & Down', 2009, ['Comedy', 'Drama', 'Sport'], 6),
  ('ff', 'Forensic Files', 1996, ['Documentary', 'Crime'], 13),
  ('ff2', 'Forensic Files II', 2020, ['Reality', 'Documentary', 'Crime', 'Mystery'], 30),
  ('highlander', 'Highlander: The Series', 1992, ['Science Fiction', 'Fantasy', 'Adventure', 'Action', 'Romance', 'Mystery'], 88),
  ('tyson', 'Mike Tyson Mysteries', 2014, ['Action', 'Comedy'], 69),
  ('rick', 'Rick and Morty', 2013, ['Science Fiction', 'Comedy', 'Animation', 'Adventure'], 81),
  ('seinfeld', 'Seinfeld', 1989, ['Comedy'], 171),
  ('shameless', 'Shameless US', 2011, ['Comedy', 'Drama'], 24),
  ('sopranos', 'The Sopranos', 1999, ['Drama', 'Crime'], 86),
  ('twinpeaks', 'Twin Peaks', 1990, ['Horror', 'Fantasy', 'Drama', 'Crime', 'Thriller', 'Romance', 'Mystery'], 48),
  ('lotus', 'The White Lotus', 2021, ['Drama', 'Comedy'], 21),
];

const _movies = <(String, List<String>)>[
  ('Back to the Future', ['Adventure', 'Comedy', 'Science Fiction']),
  ('Back to the Future Part II', ['Adventure', 'Comedy', 'Science Fiction']),
  ('Back to the Future Part III', ['Adventure', 'Comedy', 'Science Fiction']),
  ('Backdraft', ['Drama', 'Thriller', 'Action', 'Crime']),
  ('The Big Lebowski', ['Comedy', 'Crime']),
  ('Bloodsport', ['Action', 'Drama']),
  ('Days of Thunder', ['Adventure', 'Action', 'Drama']),
  ('Dazed and Confused', ['Comedy', 'Drama']),
  ('Die Hard', ['Action', 'Thriller']),
  ('The Disaster Artist', ['Comedy', 'Drama']),
  ('Dumb and Dumber', ['Comedy']),
  ("Ferris Bueller's Day Off", ['Comedy']),
  ('Footloose', ['Drama', 'Romance']),
  ('Ghostbusters', ['Comedy', 'Fantasy']),
  ('Ghostbusters II', ['Comedy', 'Fantasy']),
  ('The Goonies', ['Adventure', 'Comedy', 'Family']),
  ('Indiana Jones and the Last Crusade', ['Adventure', 'Action']),
  ('Indiana Jones and the Temple of Doom', ['Adventure', 'Action']),
  ('Inglourious Basterds', ['Drama', 'Thriller', 'War']),
  ('The Princess Bride', ['Fantasy', 'Comedy', 'Romance', 'Adventure']),
  ('Pulp Fiction', ['Thriller', 'Crime', 'Comedy']),
  ('Raiders of the Lost Ark', ['Adventure', 'Action']),
  ('The Rocky Horror Picture Show', ['Comedy', 'Science Fiction', 'Horror']),
  ('The Room', ['Drama', 'Romance']),
  ('Rushmore', ['Comedy', 'Drama']),
  ('The Sandlot', ['Family', 'Comedy', 'Drama']),
  ('Teenage Mutant Ninja Turtles', ['Science Fiction', 'Action', 'Adventure', 'Comedy', 'Family']),
  ('Teenage Mutant Ninja Turtles II: The Secret of the Ooze', ['Science Fiction', 'Adventure', 'Action', 'Comedy', 'Family']),
  ('The Terminator', ['Action', 'Thriller', 'Science Fiction']),
  ('Terminator 2: Judgment Day', ['Action', 'Thriller', 'Science Fiction']),
  ("There's Something About Mary", ['Romance', 'Comedy']),
  ('Tommy Boy', ['Comedy']),
  ('Top Gun', ['Action', 'Drama', 'Romance']),
  ('Top Gun: Maverick', ['Action', 'Drama']),
  ('Universal Soldier', ['Thriller', 'Action', 'Science Fiction']),
  ("Wayne's World", ['Comedy', 'Music']),
  ("Wayne's World 2", ['Comedy', 'Music']),
  ('The Wedding Singer', ['Romance', 'Comedy']),
];
