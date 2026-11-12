# Custom sprites (optional)

The app draws a placeholder pink blob in code. To use your own character, drop PNG
frames in this folder named like a Shimeji-ee image set: `shime1.png`, `shime2.png`, ...

The app switches to images automatically when `shime1.png` exists. Which frame is
used for which pose is set in `ShimejiCompanion/CharacterView.swift` (`SpriteFrames.mapping`):

| Pose | Default frame |
|---|---|
| standing | shime1 |
| walking | shime2, shime3 |
| falling | shime4 |
| being dragged | shime5 |
| sitting | shime11 |
| climbing a wall | shime12, shime13 |
| landing | shime18 |
| sleeping | shime21 |
| jumping | shime22 |
| hanging from the ceiling | shime23, shime24 |

Frames should face **left**, like Shimeji-ee art. Commit the PNGs and the GitHub
workflow builds a new IPA with them.
