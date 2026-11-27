# v2.4 Dash Cam — foreground prototype
Rear camera, silent recording, explicit start/stop, maximum 5-minute clips and 20 stored clips. App-private support directory, no upload, playback and confirmed deletion. No automatic overwrite, no background recording, no crash-proof capture, no storage quota guarantee; physical-device and lifecycle tests required. Camera must be mounted safely and controls used only while parked. Face control is not implemented; future opt-in local gesture testing while parked only, no identity recognition or biometric storage. 
Dependencies: https://pub.dev/packages/camera ; https://pub.dev/packages/video_player ; https://pub.dev/packages/path_provider

## Reliability follow-up
Camera release requests are retained if an operation is busy, and retried after start/stop/initialize completes. Release is guarded against concurrent calls. Clips are first copied to a private .part staging file, checked for nonzero length, then renamed; failed copies are cleaned up, and existing names are not overwritten. Device lifecycle and filesystem interruption still need physical-device testing; a crash may leave a .part file that is not listed as a clip.
