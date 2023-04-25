# file_server_mobile

App meant to be use with [file-server-api](https://github.com/deafnv/file-server-api). Untested with iOS.

## Build

- Make `.env` file with `API-URL`. See `.env-template`.

- Replace host with your server domain in `android/app/src/main/AndroidManifest_template.xml`, and rename to `AndroidManifest.xml`. See for details: https://developer.android.com/guide/topics/manifest/queries-element

```xml
<queries>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="https" android:host="yourdomain.com" android:pathPrefix="/retrieve" />
    </intent>
</queries>
```
