import QtQuick 2.0
import Sailfish.Silica 1.0
import QtQml.Models 2.2
import FileDownloader 1.0

Page {
    id: feedPage

    SilicaListView {
        id: listView
        anchors.fill: parent

        PullDownMenu {
            busy: feedModel.busy
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
            MenuItem {
                text: qsTr("Community")
                //onClicked: pageStack.push(Qt.resolvedUrl("CommunityPage.qml"))
                onClicked: Qt.openUrlExternally("http://community.badvoltage.org?mobile_view=1")
            }
            MenuItem {
                text: qsTr("Mark all as listened")
                onClicked: {
                    for (var i=0; i < feedModel.count; i++) {
                        if (listenedEpisodes.value(feedModel.get(i).title, false) === false)
                            listenedEpisodes.setValue(feedModel.get(i).title, true)
                    }
                }
                visible: numNewEpisodes > 1
            }

            MenuItem {
                text: feedModel.busy ? qsTr("Updating...") : qsTr("Update")
                enabled: !feedModel.busy
                onClicked: feedModel.update()
            }
            MenuLabel {
                text: qsTr("Last update") + ": " + settings.updateTime
            }
        }

        header: PageHeader {
            //: Header of the feed page
            title: qsTr("Bad Voltage")
        }

        model: DelegateModel {
            model: feedModel

            delegate: ListItem {
                id: episode
                width: parent.width
                contentHeight: Theme.itemSizeMedium
                property bool isListened: listenedEpisodes.value(title, false, Boolean)
                Connections {
                    target: listenedEpisodes
                    onValueChanged: if (key === title) isListened = listenedEpisodes.value(title, false, Boolean)
                }
                onClicked: pageStack.push(Qt.resolvedUrl("EpisodePage.qml"), {index: index, episode: model})

                FileDownloader {
                    id: downloader
                    url: enclosure_url
                    onIsDownloadingChanged: {
                        if (isDownloading)
                            episode.DelegateModel.inPersistedItems = 1
                        else
                            episode.DelegateModel.inPersistedItems = false
                    }
                    onIsDownloadedChanged: {
                        var currentIndex = audioPlaylist.currentIndex
                        audioPlayer.stop()
                        audioPlaylist.removeItem(index)
                        audioPlaylist.insertItem(index, downloader.isDownloaded ? "file://" + downloader.fullName : enclosure_url)
                        audioPlaylist.currentIndex = currentIndex
                        if (currentIndex >= 0) audioPlayer.play()
                    }
                }

                Rectangle {
                    id: progressRectangle
                    visible: downloader.isDownloading
                    height: parent.height
                    width: downloader.progress * parent.width
                    color: Theme.highlightColor
                    opacity: 0.2
                }

                Label {
                    id: numberLabel
                    x: Theme.horizontalPageMargin
                    anchors.bottom: parent.verticalCenter
                    text: title.split(": ", 1)[0].trim()
                    color: Theme.highlightColor
                }

                Label {
                    id: titleLabel
                    anchors.bottom: parent.verticalCenter
                    anchors.left: numberLabel.right
                    anchors.leftMargin: Theme.paddingSmall
                    anchors.right: playingIcon.visible ? playingIcon.left : parent.right
                    text: title.split(": ", 2)[1].trim()
                    truncationMode: TruncationMode.Fade
                    color: episode.highlighted || audioPlayer.isSameSource(enclosure_url) ? Theme.highlightColor : Theme.primaryColor
                }

                Image {
                    id: isNewIcon
                    //opacity: isListened.value ? 0.2 : 1.0
                    visible: !isListened
                    anchors.top: parent.verticalCenter
                    x: Theme.horizontalPageMargin
                    width: Theme.iconSizeSmall
                    source: "image://theme/icon-s-new?"
                            + (episode.highlighted ? Theme.highlightColor : Theme.primaryColor)
                }

                Image {
                    id: downloadedIcon
                    //opacity: downloader.isDownloaded ? 1.0 : 0.2
                    visible: downloader.isDownloaded
                    anchors.top: parent.verticalCenter
                    anchors.left: isNewIcon.right
                    width: Theme.iconSizeSmall
                    source: "image://theme/icon-s-device-download?"
                            + (episode.highlighted ? Theme.highlightColor : Theme.primaryColor)
                }

                Label {
                    id: pubDateLabel
                    anchors.top: parent.verticalCenter
                    anchors.left: numberLabel.right
                    anchors.leftMargin: Theme.paddingSmall
                    width: parent.width - x
                    text: new Date(pubDate).toLocaleDateString()
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: episode.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }

                IconButton {
                    id: playingIcon
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    icon.source: audioPlayer.isPlaying ? "image://theme/icon-m-pause" : "image://theme/icon-m-play"
                    visible: audioPlaylist.currentIndex === index
                    onClicked: audioPlayer.isPlaying ? audioPlayer.pause() : audioPlayer.play()
                    onPressAndHold: {
                        audioPlayer.stop()
                        audioPlayer.source = ""
                    }
                }

                menu: ContextMenu {
                    MenuItem {
                        text: qsTr("Mark as listened")
                        visible: !isListened
                        onClicked: listenedEpisodes.setValue(title, true)
                    }
                    MenuItem {
                        text: qsTr("Mark as new")
                        visible: isListened
                        onClicked: listenedEpisodes.setValue(title, false)
                    }
                    MenuItem {
                        text: qsTr("Download") + " (" + (downloadSize / 1024 / 1024).toPrecision(3) + " MB)"
                        visible: !downloader.isDownloaded && !downloader.isDownloading
                        onClicked: downloader.startDownload()
                    }
                    MenuItem {
                        text: qsTr("Abort download") + " (" + (downloadSize / 1024 / 1024 * downloader.progress).toPrecision(3) + "/" + (downloadSize / 1024 / 1024).toPrecision(3) + " MB)"
                        visible: downloader.isDownloading
                        onClicked: downloader.abortDownload()
                    }
                    MenuItem {
                        text: qsTr("Delete audio file") + " (" + (downloadSize / 1024 / 1024).toPrecision(3) + " MB)"
                        visible: downloader.isDownloaded
                        onClicked: Remorse.itemAction(episode, qsTr("Deleting audio file"), function() { downloader.deleteFile() })
                    }
                    Text {
                        id: descriptionText
                        width: parent.width - 2*Theme.horizontalPageMargin
                        height: contentHeight + Theme.paddingMedium
                        x: Theme.horizontalPageMargin
                        wrapMode: Text.Wrap
                        textFormat: Text.RichText
                        color: Theme.highlightColor
                        font.pixelSize: Theme.fontSizeSmall
                        text: description
                    }
                }
            }
        }

        section.property: "title"
        section.criteria: ViewSection.FirstCharacter
        section.labelPositioning: ViewSection.CurrentLabelAtStart
        section.delegate: SectionHeader {
            text: qsTr("Season") + " " + section
        }

        ViewPlaceholder {
            text: qsTr("No shows available")
            hintText: qsTr("Pull down to update")
            enabled: feedModel.count === 0 && !feedModel.busy
        }

        BusyIndicator {
            anchors.centerIn: parent
            size: BusyIndicatorSize.Large
            running: feedModel.count === 0 && feedModel.busy
        }

        VerticalScrollDecorator { flickable: listView }
    }
}
