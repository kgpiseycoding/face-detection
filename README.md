# Face Detection

Users and four enrollment photos (face forward, after a blink, and turned to
each side) are stored in the app's local private storage. A FaceNet-style model
generates local face embeddings so enrollment poses can be checked against one
another and a captured face can be matched against enrolled users. Photos and
embeddings are not sent to a server. The app does not encrypt this data, and
device backup settings may copy app data. Uninstalling the app normally removes
its local data. Face photos and embeddings are sensitive personal data; protect
access to the device.

The bundled model file is about 94 MB. Its recognition accuracy has not been
independently validated for this app, and its model-specific distribution
rights should be confirmed before publishing.

The iOS Runner explicitly links TensorFlow Lite C 2.12.0 and preserves
`TfLiteInterpreterOptionsCreate` for Dart FFI. Keep the CocoaPods dependency
and Runner linker settings when changing the iOS build configuration.
Enrollment photos are normalized to upright JPEGs before face validation so
camera orientation metadata does not interfere with detection.

Open a user's photo gallery to inspect each sample or share the JPEGs through
the phone's share sheet. Sharing requires confirmation and sends the selected
photos outside this app. The Verify face screen checks a still photo captured
from the phone camera; it is not a continuous CCTV connection.

Face matching can return false matches or reject the right person depending on
lighting, camera quality, pose, and the threshold. It is not liveness detection
or a secure authentication method and must not be used by itself for access
control or other consequential security decisions. Test it with representative
people and conditions before relying on its results.
