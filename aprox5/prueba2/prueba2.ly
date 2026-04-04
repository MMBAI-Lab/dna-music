\version "2.24.0"

% ============================================================
% ABC MÃºsica MollÃ¡ â aprox5/prueba2
% 4 voces SATB: soprano y bajo desde datos de ADN,
%               alto y tenor como correcciÃ³n armÃ³nica
%
% Colores:
%   Rojo  = Soprano (major groove) â datos
%   Negro = Alto y Tenor           â correcciÃ³n armÃ³nica
%   Azul  = Bajo (minor groove)    â datos
%
% Secuencia ADN:
%   GCAACGTGCTATGGAAGCGCAATAAGTACCAGGAGCGCAGAAACAGCTCTGCGCGCAGG
%   CGCAAGACTGAGCGCATTGGGGACACTACGCGCGAACTCAAAGGTTGGCGCGACCGAAT
%   GTAATTGCGCGGAGGGCCGGGTGGGCGCGTTAGATTAAAATTGCGCTACGCGGATCGAG
%   AGCGCTGATATACGATGCAGCGCTGGCATGAAGCGACGCGCTTGTGACGGCTAGGGC
%   (234 bases, 231 tetranucleÃ³tidos solapados)
%
% Transformaciones:
%   - Escala: Re menor natural (D E F G A Bb C)
%   - Soprano: major groove, registro D4-D6, snap Re menor, voice leading
%   - Bajo:    minor groove, registro D2-D4, snap Re menor, voice leading
%   - Alto:    correcciÃ³n armÃ³nica, G3-C5, minimiza disonancia con bajo
%   - Tenor:   correcciÃ³n armÃ³nica, C3-G4, entre bajo y alto
%   - DuraciÃ³n: normalizaciÃ³n lineal del tiempo de vida media (aprox4)
%   - Tempo: 72 BPM
% ============================================================

colorRojo = {
  \override NoteHead.color   = #red
  \override Stem.color       = #red
  \override Flag.color       = #red
  \override Beam.color       = #red
  \override Accidental.color = #red
  \override Dots.color       = #red
}

colorAzul = {
  \override NoteHead.color   = #blue
  \override Stem.color       = #blue
  \override Flag.color       = #blue
  \override Beam.color       = #blue
  \override Accidental.color = #blue
  \override Dots.color       = #blue
}

soprano = {
  \clef treble
  \key d \minor
  \tempo "Andante moderato" 4 = 72
  \cadenzaOn
  \colorRojo
  e'8 g'8 f'8. a'8 e'8. a'8 d''4. g'8 \bar "|" g'8 bes'8. f'8 f'8. g'8. bes'8. d''8 d''4. \bar "|" f''8 c''2 e''8 g''8 c''8. bes'8 g'8 d''8. \bar "|" g'8. c''8. f'8. f'8. d'8 g'8 a'8. f'8. \bar "|" d''8 d''4. f''8 c''2 c''8 c''8 g'8. bes'8. \bar "|" d''8. f''4 g''8 c''8 e''4. c''8 a'4 c''8 \bar "|" c''8 c''2 f'8 a'4 f'8 c''2 c''8 g'8 \bar "|" g'8. c''4. f'8 c''2 e''8 f''8 d''8 c''4 \bar "|" f'4 c''8 d''8 d''4 c''8 d''4. f''8 c''2 \bar "|" a'8 c''8. g'8 e'8 d'8. f'8. c''4 g'8. \bar "|" d''8. c''8 g'4 c''8 g'8 d''8. e''8 a'4 \bar "|" f'8 a'4 f'8 f'4 c''8. c''4 e''8. d''4 \bar "|" e''8 g''8. g''8. c''8 d''4 g'8. g'8 e'8 \bar "|" d'8. c''4. f'8 a'4 f'8 a'4 g'8. f'8. \bar "|" f'8 f'4 c''8. c''8. c''8. e''4 a'8 a'8. \bar "|" d''8. g'8 e'8 c''2 f'8 a'4 g'8 a'4 \bar "|" f'8. c''8 bes'4 g'8. c''4. f'8. f'8 d'8. \bar "|" bes'4 g'8. f'8 d'8. g'8. c''4. f'8 a'4 \bar "|" e'8 e'8. g'8 d''8 d''8. bes'4 c''8. bes'8. \bar "|" e'8 bes'8. c''8. d''8. d''8. g'8 e'8 c''2 \bar "|" f'8 d'4. g'8 g'8 d''8. e''8 a'4 g'8 \bar "|" a'4 a'4 bes'8. g'4. f'8 c''8. f'8. a'4 \bar "|" c''8 d''4. f''8 d''4. c''8 d''8 f''4 bes'8. \bar "|" c''8. a'8 c''8. d''8. f''8 g''4. c''8. g'8 \bar "|" g'4 c''8 c''8 d''4. f''8 d''4. c''8 d''8 \bar "|" d''8. c''4. a'8 c''8. g'8 d''4 bes'8. d''8 \bar "|" d''4. f''8 a''4 f''4 e''8 a'4 f'8 d'4. \bar "|" d'8 f'8 e'8 c''8. e''8 f''4. f''4 f''8 \bar "|" f''8. d''2 g'8 d''8 g'8 bes'4 g'8.
  \bar "|."
}

alto = {
  \clef treble
  \key d \minor
  \cadenzaOn
  c'8 bes8 c'8. c'8 c'8. bes8 a4. a8 \bar "|" bes8 bes8. a8 a8. g8. g8. a8 bes4. \bar "|" bes8 a2 a8 a8 bes8. c'8 bes8 bes8. \bar "|" a8. a8. bes8. c'8. bes8 bes8 a8. a8. \bar "|" a8 bes4. bes8 a2 bes8 bes8 bes8. bes8. \bar "|" a8. g4 a8 bes8 bes4. a8 a4 a8 \bar "|" bes8 a2 a8 a4 a8 a2 bes8 bes8 \bar "|" c'8. c'4. bes8 a2 a8 a8 a8 bes4 \bar "|" bes4 a8 a8 a4 a8 bes4. bes8 a2 \bar "|" a8 bes8. bes8 bes8 a8. a8. a4 a8. \bar "|" bes8. a8 a4 a8 a8 bes8. a8 a4 \bar "|" a8 a4 a8 g4 g8. g4 a8. a4 \bar "|" g8 a8. a8. g8 g4 a8. bes8 bes8 \bar "|" a8. a4. a8 a4 a8 a4 a8. bes8. \bar "|" a8 g4 a8. bes8. a8. bes4 a8 g8. \bar "|" g8. a8 a8 a2 a8 a4 a8 a4 \bar "|" a8. bes8 bes4 a8. a4. bes8. a8 bes8. \bar "|" c'4 c'8. c'8 a8. a8. a4. a8 a4 \bar "|" a8 g8. a8 g8 a8. a4 a8. a8. \bar "|" a8 bes8. bes8. a8. bes8. bes8 a8 a2 \bar "|" a8 bes4. bes8 a8 bes8. a8 a4 a8 \bar "|" a4 g4 g8. g4. g8 g8. g8. a4 \bar "|" a8 bes4. bes8 bes4. bes8 a8 g4 a8. \bar "|" a8. a8 g8. g8. a8 a4. a8. a8 \bar "|" a4 bes8 bes8 bes4. bes8 bes4. bes8 bes8 \bar "|" a8. g4. g8 g8. a8 bes4 a8. a8 \bar "|" bes4. bes8 a4 bes4 g8 a4 a8 bes4. \bar "|" a8 a8 bes8 a8. a8 a4. bes4 a8 \bar "|" a8. a2 a8 g8 a8 bes4 a8.
  \bar "|."
}

tenor = {
  \clef bass
  \key d \minor
  \cadenzaOn
  e8. a8 g8. g8 f8. f8. e8. f8 \bar "|" a8. a8 c8. c8 f8 e8. e8 e8 \bar "|" f4. g8. g8. f8 a8. g8 a8. c8 \bar "|" c8 c8. a8. g8 g8. g8. g8 g8 \bar "|" g8. a8 a4. g8. g8. f4 f8 f8. \bar "|" g8. f8. g8. a8. c8. c8. g8. f4 \bar "|" f8. g8. f4. g8. f4. g8. g8. g8. \bar "|" g8 g8 f4. g8. g8. g8. f8. a4 \bar "|" a4 g8 g4 g8. g8. a8 a4. g8. \bar "|" g8 a4. a8 a4 g8. g8. f8 f8 \bar "|" f8. e8 e8. f8 e8. f8. e8 g8. \bar "|" f4. g8. f4 f8. c8 e8 g8 g8. \bar "|" f4 g8 f8. f8. c8 f8. a8 a4 \bar "|" g8 g8 f4. g8. f4 f8 f8. e8 \bar "|" f4. f8. f8. a4. g8 a8 g8. f8 \bar "|" c2 f8 e8. g8. f4. g8. g4 g8 \bar "|" g8 g4 g8 f8 e8. a8 c2 a8 \bar "|" g8 g8 a4 g8. g8 g8 f4. g8. \bar "|" g8 f8. f8 f8. f8. f8 e4. f8 \bar "|" f8. f8. g8. f8 e2 f8 e8. g8. \bar "|" f4. a8 a8 g8. g8. g8 g8. g4 \bar "|" g8 f8. c4 e8 e4 c8 c8. g8. \bar "|" g8. a8 a4. a8 a8. g4 f8 f4 \bar "|" e8 e8. f8 f8. g8. g8 f8. f8 \bar "|" g8. g8. g8. g8 f4. a8 a8. c8. \bar "|" c8 f8. e8 c8. c8. a8. g8. f8 \bar "|" e8 f4 f8 e8. e8 g8. f4. a8 \bar "|" c8 c8. a8 c8 f8. c8. a8. c8. \bar "|" e8 e8 f8 f8. g8 a8 g8
  \bar "|."
}

bass = {
  \clef bass
  \key d \minor
  \cadenzaOn
  \colorAzul
  c8. g8 e8. c8 a,8. bes,8. c8. d8 \bar "|" g8. g8 a8. c'8 e8 c8. a,8 g,8 \bar "|" d4. f8. c8. d8 g8. e8 g8. bes8 \bar "|" c'8 a8. g8. e8 bes,8. bes,8. c8 f8 \bar "|" c8. g8 d4. f8. bes,8. d4 d8 bes,8. \bar "|" f8. e8. f8. g8. bes8. c'8. f8. d4 \bar "|" bes,8. f8. d4. f8. d4. f8. bes,8. bes,8. \bar "|" e8 c8 d4. f8. c8. c8. d8. g4 \bar "|" g4 c8 f4 f8. c8. g8 d4. f8. \bar "|" c8 g4. d8 d4 f8. c8. a,8 f,8 \bar "|" bes,8. c8 c8. d8 c8. bes,8. c8 f8. \bar "|" d4. f8. d4 e8. g8 c8 f8 f8. \bar "|" e4 f8 d8. e8. g8 d8. g8 d4 \bar "|" c8 c8 d4. f8. d4 a,8 f,8. g,8 \bar "|" d4. e8. d8. g4. f8 g8 c8. e8 \bar "|" g2 d8 c8. f8. d4. f8. c4 c8 \bar "|" f8 bes,4 g,8 f,8 c8. g8 g2 g8 \bar "|" e8 e8 f4 f8. f8 c8 d4. f8. \bar "|" c8 e8. a,8 e8. a,8. f,8 c4. d8 \bar "|" d8. bes,8. e8. a,8 g,2 d8 c8. f8. \bar "|" d4. g8 d8 c8. bes,8. c8 f8. c4 \bar "|" c8 e8. g4 c8 c4 g8 g8. f8. \bar "|" c8. g8 d4. g8 g8. f4 e8 d4 \bar "|" c8 c8. e8 bes,8. f8. c8 d8. d8 \bar "|" f8. bes,8. g,8. g,8 d4. g8 g8. bes8. \bar "|" c'8 e8. c8 g8. a8. g8. c8. a,8 \bar "|" g,8 d4 a,8 g,8. c8 f8. d4. g8 \bar "|" a8 c'8. g8 a8 d8. g8. g8. g8. \bar "|" c8 c8 d8 e8. f8 g8 f8
  \bar "|."
}

\score {
  \new ChoirStaff <<
    \new Staff \with { instrumentName = "S." shortInstrumentName = "S." }
      { \soprano }
    \new Staff \with { instrumentName = "A." shortInstrumentName = "A." }
      { \alto }
    \new Staff \with { instrumentName = "T." shortInstrumentName = "T." }
      { \tenor }
    \new Staff \with { instrumentName = "B." shortInstrumentName = "B." }
      { \bass }
  >>
  \layout {
    indent = 2\cm
    \context {
      \Score
      \omit BarNumber
    }
  }
}
