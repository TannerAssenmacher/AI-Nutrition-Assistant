# iOS Notification Setup

## Required: Update Info.plist

Add the following to your `ios/Runner/Info.plist` file before the final `</dict></plist>`:

```xml
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>remote-notification</string>
	</array>
	<key>UIUserNotificationSettings</key>
	<dict>
		<key>UIUserNotificationTypeAlert</key>
		<true/>
		<key>UIUserNotificationTypeBadge</key>
		<true/>
		<key>UIUserNotificationTypeSound</key>
		<true/>
	</dict>
```

## Location in File
The Info.plist should look something like this:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<!-- Existing keys like CFBundleName, etc. -->
	
	<!-- ADD THIS SECTION -->
	<key>UIBackgroundModes</key>
	<array>
		<string>fetch</string>
		<string>remote-notification</string>
	</array>
	<key>UIUserNotificationSettings</key>
	<dict>
		<key>UIUserNotificationTypeAlert</key>
		<true/>
		<key>UIUserNotificationTypeBadge</key>
		<true/>
		<key>UIUserNotificationTypeSound</key>
		<true/>
	</dict>
	<!-- END OF ADDITION -->
	
</dict>
</plist>
```

After making this change, you may need to:
1. Clean your build: `flutter clean`
2. Get dependencies: `flutter pub get`
3. Rebuild: `flutter run`
