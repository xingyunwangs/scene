# Scene capture handoff

Scene is standalone. If Mirror is installed, Scene may write one `CaptureDraft` JSON file to:

`~/Library/Application Support/SovereignContext/Handoffs`

It then launches the bundle identifier `com.sovereign.Mirror` and posts the distributed notification `com.sovereign.mirror.capture` with that file path. Schema version `1` is frozen by `Docs/capture-draft-v1.json`. Missing Mirror or an unknown schema version fails only that action; reading remains available.

Neither app shares a database or lifecycle. Mirror owns saved Markdown. Scene never edits a book.
