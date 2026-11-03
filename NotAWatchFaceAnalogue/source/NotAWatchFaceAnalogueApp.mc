import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Entry point. The watch creates this class first and asks it for the view.
class NotAWatchFaceAnalogueApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
    }

    function onStop(state) {
    }

    function getInitialView() {
        return [new NotAWatchFaceAnalogueView()];
    }
}
