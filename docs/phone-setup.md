# Phone setup

Both phones need the same four things: the broker address, the private CA, a broker username and password, and the shared encryption key. Menu names below match recent OwnTracks releases and may differ by version.

## Values to have ready

| Setting | Value |
|---|---|
| Mode | MQTT |
| Host | Server IP from `terraform output -raw server_ip` |
| Port | 8883 |
| TLS | On |
| CA certificate | `pki/out/ca.crt` (Android), `pki/out/ca.cer` (iPhone) |
| Username / password | From `owntracks-add-user`; Proton Pass `OwnTracks MQTT - <user>` |
| Device ID | Short name, e.g. `phone` |
| Tracker ID | Two characters shown on the map, e.g. initials |
| Encryption key | Proton Pass `OwnTracks encryption key`, identical on both phones |

Generate the encryption key once: 32 random characters (OwnTracks uses the first 32 bytes), and store it in Proton Pass before setting up either phone.

## Android (GrapheneOS)

1. Install **OwnTracks** from F-Droid. The F-Droid build is the `oss` flavor: Android location APIs and OpenStreetMap, no Google Play Services.
2. Copy `ca.crt` to the phone (USB, File transfer, `Download/`).
3. OwnTracks → Preferences → **Connection**:
   - Mode: MQTT
   - Host, port, TLS on
   - CA certificate: select `Download/ca.crt`
   - Identification: username, password, device ID, tracker ID
4. Preferences → **Advanced** → Encryption key: paste the shared key.
5. Delete `Download/ca.crt`.
6. Permissions (Settings → Apps → OwnTracks):
   - Location: **Allow all the time**, precise on
   - Notifications: allow
   - Battery: **Unrestricted**, or GrapheneOS stops background reporting
   - Deny everything else
7. Monitoring mode: **Significant** for daily use (reports on large moves, low battery cost); **Move** while traveling for frequent updates.

## iPhone

1. Install **OwnTracks** from the App Store.
2. Send `ca.cer` to the iPhone (AirDrop or a Signal attachment) and open it. iOS offers to download a profile.
3. Settings → General → **VPN & Device Management** → install the downloaded profile.
4. Settings → General → About → **Certificate Trust Settings** → turn on full trust for **OwnTracks Private CA**.
5. OwnTracks → settings:
   - Mode: MQTT
   - Host, port, TLS on
   - Authentication: username and password
   - Device ID and tracker ID
   - Encryption key ("secret"): paste the shared key
6. iOS Settings → OwnTracks → Location: **Always**, precise on; Background App Refresh on.
7. Monitoring mode: **Significant** for daily use.

The CA carries a name constraint limited to the server IP, so trusting it on the iPhone does not let it vouch for any other site.

## Check

On each phone, publish a location (OwnTracks map → publish button). The other phone should show the tracker ID on its map within a few seconds. If the connection status shows a TLS error, the CA is not trusted: recheck step 3 on Android or steps 3–4 on iPhone.

## Stopping sharing

Either person can stop at any time: switch OwnTracks to Quiet mode, or remove the app. To revoke a user on the server, see [operations.md](operations.md).
