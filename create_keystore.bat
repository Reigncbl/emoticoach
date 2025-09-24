@echo off
echo Creating keystore for EmotiCoach app...
keytool -genkey -v -keystore emoticoach-release-key.keystore -keyalg RSA -keysize 2048 -validity 10000 -alias emoticoach -storepass emoticoach123 -keypass emoticoach123 -dname "CN=EmotiCoach, OU=Development, O=EmotiCoach Team, L=City, S=State, C=PH"
echo Keystore created successfully!
pause
