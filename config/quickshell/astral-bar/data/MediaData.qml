pragma Singleton
import "../../common" as Common
import Quickshell.Services.Mpris

Common.MediaService { rawPlayers: Mpris.players.values }
