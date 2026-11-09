import Foundation

/// Read-only AppleScript. Nothing here ever sends a transport command to Music.
enum MusicScripts {
    static let separator: Character = "\u{1F}"

    /// state, persistent ID, name, artist, album, position (ms), duration (ms), separated by U+001F.
    /// Every field is read in its own try block: some streamed tracks have no duration, and
    /// recent macOS builds sometimes throw -1728 for `player position` right after a track change.
    static let nowPlaying = """
    set sepChar to (ASCII character 31)
    with timeout of 3 seconds
        tell application "Music"
            set stateText to (player state as string)
            if stateText is "stopped" then return "STOPPED"
            set posMs to 0
            try
                set posMs to (round ((player position) * 1000)) as integer
            end try
            set nameText to ""
            set artistText to ""
            set albumText to ""
            set durMs to 0
            set idText to ""
            try
                set trk to current track
                try
                    set nameText to name of trk
                end try
                try
                    set artistText to artist of trk
                end try
                try
                    set albumText to album of trk
                end try
                try
                    set durMs to (round ((duration of trk) * 1000)) as integer
                end try
                try
                    set idText to persistent ID of trk
                end try
            end try
            return stateText & sepChar & idText & sepChar & nameText & sepChar & artistText & sepChar & albumText & sepChar & (posMs as string) & sepChar & (durMs as string)
        end tell
    end timeout
    """

    static let artwork = """
    with timeout of 5 seconds
        tell application "Music"
            return raw data of artwork 1 of current track
        end tell
    end timeout
    """
}
