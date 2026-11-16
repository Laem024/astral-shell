pragma Singleton
import Quickshell.Services.Mpris

MediaService {
  // Quickshell exposes values at runtime on its untyped model.
  // qmllint disable missing-property
  rawPlayers: Mpris.players.values
  // qmllint enable missing-property
}
