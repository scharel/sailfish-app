import QtQuick 2.0
import Sailfish.Silica 1.0
import Nemo.Configuration 1.0
import QtQuick.XmlListModel 2.0
import QtMultimedia 5.6
import "pages"
import "cover"

ApplicationWindow
{
    id: appWindow

    property int numNewEpisodes: 0
    ConfigurationGroup {
        id: settings
        path: "/apps/harbour-badvoltage/settings"
        property string updateTime: qsTr("never")
    }
    ConfigurationGroup {
        id: listenedEpisodes
        path: "/apps/harbour-badvoltage/listened_episodes"
        onValueChanged: feedModel.parseEpisodes()
    }
    ConfigurationGroup {
        id: episodeAudioPositions
        path: "/apps/harbour-badvoltage/audio_positions"
    }

    initialPage: Component { FeedPage{ } }
    cover: Component { CoverPage{ } }

    Audio {
        id: audioPlayer
        audioRole: Audio.MusicRole
        property bool isPlaying: false
        property bool isLoading: status === Audio.Loading
        playlist: Playlist {
            id: audioPlaylist
            playbackMode: Playlist.CurrentItemOnce
            onItemChanged: console.log(itemCount)
        }

        onPlaybackStateChanged: {
            if (playbackState === Audio.PlayingState) {
                isPlaying = true
                console.log("Started playback of:")
            }
            else {
                isPlaying = false
                console.log("Stopped playback of:")
            }
            console.log(audioPlaylist.currentItemSource + " (" + audioPlaylist.currentIndex + ")")
        }
        onPositionChanged:
            if (seekable && playlist.currentIndex >= 0)
                episodeAudioPositions.setValue(feedModel.get(playlist.currentIndex).title, position)
        onSeekableChanged:
            if (seekable && episodeAudioPositions.value(feedModel.get(playlist.currentIndex).title, 0) > 0)
                seek(episodeAudioPositions.value(feedModel.get(playlist.currentIndex).title, position))

        function isSameSource(s) {
            var s1 = decodeURI(s)
            var s2 = decodeURI(audioPlaylist.currentItemSource).replace("file://", "")
            return s1 === s2 ? true : false
        }
    }

    function msec2timeString(msec) {
        return new Date(msec + new Date(msec).getTimezoneOffset() * 60000).toLocaleString(Qt.locale(), msec > 3600000 ? "H:mm:ss" : "mm:ss")
    }
    function timeString2msec(time) {
        var times = time.split(":", 3)
        return times[0] * 3600000 + times[1] * 60000 + times[2] * 1000
    }

    XmlListModel {
        id: feedModel

        property string file: StandardPaths.data + "/feed.xml"
        property string url: "https://www.badvoltage.org/feed/mp3"
        property bool busy: false

        source: file
        query: "/rss/channel/item"
        namespaceDeclarations: "declare namespace itunes='http://www.itunes.com/dtds/podcast-1.0.dtd'; declare namespace content='http://purl.org/rss/1.0/modules/content/';"

        XmlRole { name: "title"; query: "title/string()"; isKey: false }
        XmlRole { name: "pubDate"; query: "pubDate/string()"; isKey: false }
        XmlRole { name: "guid"; query: "guid/string()"; isKey: true }
        XmlRole { name: "downloadSize"; query: "enclosure/@length/string()"; isKey: false }
        XmlRole { name: "description"; query: "description/string()"; isKey: false }
        XmlRole { name: "content_encoded"; query: "content:encoded/string()"; isKey: false }
        XmlRole { name: "enclosure_url"; query: "enclosure/@url/string()"; isKey: false }
        XmlRole { name: "duration"; query: "itunes:duration/string()"; isKey: false }

        Component.onCompleted: { parseEpisodes(); update() }
        onCountChanged: parseEpisodes()

        function update() {
            console.log("Updating feed...")
            busy = true
            var feedReq = new XMLHttpRequest
            feedReq.open("GET", url)
            feedReq.onreadystatechange = function() {
                if (feedReq.readyState === XMLHttpRequest.DONE) {
                    if (feedReq.status === 200) {
                        console.log("Loaded feed from web")
                        var data = feedReq.responseText
                        var filePut = new XMLHttpRequest
                        filePut.open("PUT", file)
                        filePut.onreadystatechange = function() {
                            if (filePut.readyState === XMLHttpRequest.DONE) {
                                reload()
                            }
                        }
                        filePut.send(data)
                        settings.updateTime = new Date().toLocaleString(Qt.locale(), Locale.ShortFormat)
                    }
                    else {
                        console.log("Error loading feed from web")
                    }
                    busy = false
                }
            }
            feedReq.send()
        }

        function parseEpisodes() {
            var num = 0
            for (var i = 0; i < count; i ++) {
                audioPlaylist.insertItem(i, get(i).enclosure_url)
                if (!listenedEpisodes.value(get(i).title, false, Boolean) === true)
                    num ++
            }
            numNewEpisodes = num
            return numNewEpisodes
        }
    }

    allowedOrientations: Orientation.All
    _defaultPageOrientations: Orientation.Portrait
}
