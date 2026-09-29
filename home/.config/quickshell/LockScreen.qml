// Native lock screen (replaces hyprlock): Wayland's ext-session-lock
// protocol + PAM. Locked with `bloquear` (~/.local/bin), which calls
// `qs ipc call lock lock` and, if the shell does not answer, falls back to hyprlock.
// The content of each monitor is in LockSurface.qml.
//
// PAM starts on lock and on any key or mouse movement, so
// face recognition (Howdy) starts by itself; the password is handed over when PAM
// asks for it (if typed earlier, it is kept until then). After a failure it does not retry
// by itself: it waits for the next key.
//
// PAM services (system/etc/pam.d/ in the repo):
//   quickshell-lock       password (and unlocks the GNOME keyring)
//   quickshell-lock-cara  Howdy and, if it fails, the same as quickshell-lock
// The face is only used with the keyring already unlocked: after autologin it is locked and
// only the password unlocks it, so the first unlock is always with the password.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

Scope {
    id: root

    // State shared by all monitors
    property string buffer: ""           // typed password
    property string status: ""           // PAM message (face, attempts…) or error
    property bool statusIsError: false
    property bool submitted: false       // Enter pressed: handed over when PAM asks for it
    property bool busy: false            // password handed over, waiting for PAM
    property bool testing: false         // `qs ipc call lock prueba`: unlocks by itself
    property bool face: false            // the current attempt uses the face
    property bool scanning: false        // Howdy looking for the face
    property real promptSince: 0         // when PAM asked for the password (ms)
    readonly property bool locked: sessionLock.locked

    // "Locked session" marker: if the shell restarts (or starts after
    // autologin), it locks again on load
    readonly property string marker: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-bloqueo"

    function lock() {
        // A real lock during a test turns it into a real lock
        testing = false
        if (sessionLock.locked) return
        Quickshell.execDetached(["touch", marker])
        buffer = ""; status = ""; statusIsError = false; submitted = false; busy = false
        retryWhenPrompted = false
        sessionLock.locked = true
        startPam()
    }

    function unlock() {
        Quickshell.execDetached(["rm", "-f", marker])
        if (pam.active) pam.abort()      // abort() does not emit completed
        testing = false
        sessionLock.locked = false
        buffer = ""; status = ""; statusIsError = false; submitted = false; busy = false
        scanning = false
    }

    // Picks the service (face?) and starts PAM. Asynchronous: it checks the keyring first
    function startPam() {
        if (!sessionLock.locked || pam.active || keyringCheck.running) return
        if (faceInstalled) keyringCheck.running = true
        else beginPam(false)
    }

    function beginPam(useFace) {
        if (!sessionLock.locked || pam.active) return
        face = useFace
        pam.config = useFace ? "quickshell-lock-cara" : passwordService
        // With Howdy installed but the keyring locked (after boot): so it does not look like a failure
        if (faceInstalled && !useFace && status === "") {
            status = I18n.tr("After boot, password: it unlocks the keyring")
            statusIsError = false
        }
        if (!pam.start()) { status = I18n.tr("Could not start PAM"); statusIsError = true }
    }

    // Any key or movement. If PAM is stopped (after a failure), it starts
    // again. If the face already failed a while ago (idle lock: it was tried with
    // nobody in front) and nothing has been typed yet, it retries
    function activity() {
        if (!pam.active) { startPam(); return }
        if (pam.responseRequired && Date.now() - promptSince > 10000) retryFace()
    }

    // Tries the face again if it already failed (nobody in front, lid closed…)
    // and nothing has been typed. If Howdy is still looking, it retries when it finishes.
    // Used by activity() and, on wake from suspend, by hypridle
    // (`qs ipc call lock reintentar`): closing the lid locks and Howdy is skipped
    // (abort_if_lid_closed), and on opening it nothing is pressed
    property bool retryWhenPrompted: false
    function retryFace() {
        if (!sessionLock.locked) return
        if (!pam.active) { startPam(); return }
        if (!face || buffer !== "" || submitted) return
        if (!pam.responseRequired) { retryWhenPrompted = true; return }
        retryWhenPrompted = false
        pam.abort()
        status = ""; statusIsError = false
        startPam()
    }

    function submit() {
        if (buffer === "" || busy) return
        submitted = true
        if (pam.active && pam.responseRequired) respondNow()
        else startPam()
    }

    function respondNow() {
        submitted = false
        busy = true
        pam.respond(buffer)
    }

    WlSessionLock {
        id: sessionLock
        surface: Component {
            WlSessionLockSurface {
                color: Theme.bg
                LockSurface { anchors.fill: parent; ctx: root }
            }
        }
    }

    // Which services exist. Without quickshell-lock, hyprlock's (same content): without a
    // service, PamContext does not start and it could not be unlocked
    property string passwordService: "hyprlock"
    property bool faceInstalled: false
    Process {
        running: true
        command: ["sh", "-c", "test -e /etc/pam.d/quickshell-lock && echo clave; " +
                              "test -e /etc/pam.d/quickshell-lock-cara && command -v howdy >/dev/null && echo cara"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.includes("clave")) root.passwordService = "quickshell-lock"
                root.faceInstalled = text.includes("cara")
            }
        }
    }

    // Keyring unlocked? (if it does not answer, password: that is what unlocks it)
    Process {
        id: keyringCheck
        command: ["busctl", "--user", "get-property", "org.freedesktop.secrets",
                  "/org/freedesktop/secrets/collection/login", "org.freedesktop.Secret.Collection", "Locked"]
        stdout: StdioCollector { onStreamFinished: root.beginPam(text.trim() === "b false") }
    }

    // Howdy messages (in English) → screen text
    function translate(msg) {
        if (msg.startsWith("Attempting facial authentication")) return I18n.tr("Looking for your face…")
        if (msg.startsWith("Failure, timeout reached")) return I18n.tr("Face not recognized")
        if (msg.startsWith("Face detection image too dark")) return I18n.tr("Image too dark to recognize the face")
        if (msg.startsWith("Identified face as")) return ""
        return msg
    }

    PamContext {
        id: pam
        property bool pamError: false    // PAM already explained the failure (e.g. account locked)

        onActiveChanged: {
            if (active) { pamError = false; root.scanning = root.face }
            else root.scanning = false
        }
        onPamMessage: {
            if (pam.responseRequired) {
                // Asks for the password: the face (if any) has already finished. The prompt
                // ("Password:") is not shown, the field is already there
                root.scanning = false
                root.promptSince = Date.now()
                if (root.submitted) root.respondNow()
                else if (root.retryWhenPrompted) Qt.callLater(root.retryFace)   // outside the PAM handler
                return
            }
            const text = root.translate(pam.message)
            if (text === "") return
            const howdy = text !== pam.message    // face failures are not serious
            root.status = text
            root.statusIsError = pam.messageIsError && !howdy
            if (pam.messageIsError && !howdy) pamError = true
        }
        onCompleted: result => {
            root.busy = false
            root.submitted = false
            if (result === PamResult.Success) { root.unlock(); return }
            root.buffer = ""
            if (!pamError) {
                root.status = result === PamResult.MaxTries ? I18n.tr("Too many attempts") : I18n.tr("Wrong password")
                root.statusIsError = true
            }
        }
        // After an error, completed(Error) arrives too: pamError keeps it from covering it
        onError: error => {
            pamError = true
            root.busy = false
            root.submitted = false
            root.status = I18n.tr("PAM error: %1").arg(PamError.toString(error))
            root.statusIsError = true
        }
    }

    // On shell startup: if the session was locked, lock again
    Process {
        running: true
        command: ["test", "-e", root.marker]
        onExited: exitCode => { if (exitCode === 0) root.lock() }
    }

    Timer {
        id: testTimer
        interval: 15000
        onTriggered: if (root.testing) root.unlock()
    }

    // qs ipc call lock lock      → lock
    // qs ipc call lock isLocked  → true/false
    // qs ipc call lock reintentar → try the face again (used by hypridle on wake)
    // qs ipc call lock prueba    → lock for 15 s and unlock by itself (to see how it looks;
    //                              does nothing if it was already locked)
    IpcHandler {
        target: "lock"
        function lock(): void { root.lock() }
        function isLocked(): bool { return sessionLock.locked }
        function reintentar(): void { root.retryFace() }
        function prueba(): void {
            if (sessionLock.locked) return
            root.lock()            // sets testing to false…
            root.testing = true    // …and here it is marked as a test
            testTimer.restart()
        }
    }
}
