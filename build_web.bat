@echo off
echo Building Flutter web...
flutter build web --release

echo Copying missing files...
copy web\favicon.png build\web\favicon.png
copy web\manifest.json build\web\manifest.json
copy web\_redirects build\web\_redirects
copy web\netlify.toml build\web\netlify.toml
xcopy web\icons build\web\icons /E /I /Y

echo.
echo Done! Upload the build\web folder to Netlify.
pause
