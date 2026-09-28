import re

p = 'android/app/src/main/AndroidManifest.xml'
s = open(p, encoding='utf-8').read()

perms = '''
    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>'''

if 'BLUETOOTH_SCAN' not in s:
    s = re.sub(r'(<manifest[^>]*>)', lambda m: m.group(1) + perms, s, count=1)

s = re.sub(r'android:label="[^"]*"', 'android:label="ALIS PROJECT"', s, count=1)
open(p, 'w', encoding='utf-8').write(s)
print('AndroidManifest berhasil dipatch')
