@echo off
setlocal EnableDelayedExpansion

goto :MAIN


REM =====================================================
REM SUBROUTINES
REM =====================================================

:DEPLOY_GITHUB
echo [INFO] Deploying to GitHub...
echo [DEBUG] Entered :DEPLOY_GITHUB OK
echo [DEBUG] GITHUB_REPO=%GITHUB_REPO%
echo [DEBUG] ZIP_NAME=%ZIP_NAME%
echo [DEBUG] ZIP_FILE=%ZIP_FILE%
call echo [DEBUG] Token starts: %%GITHUB_TOKEN:~0,4%%%%

where curl >nul 2>&1
if errorlevel 1 (
  echo [ERROR] curl not found on PATH.
  exit /b 1
)

if "%GITHUB_TOKEN%"=="" (
  echo [ERROR] GITHUB_TOKEN is empty.
  exit /b 1
)

REM ---- TEST AUTH ----
echo [DEBUG] Running curl /user test...
curl -i -s -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" https://api.github.com/user > "%TEMP%\gh_user_test.txt"
echo [DEBUG] curl /user errorlevel: %ERRORLEVEL%

echo [DEBUG] ===== GITHUB /user RESPONSE =====
type "%TEMP%\gh_user_test.txt"
echo [DEBUG] ===== END /user RESPONSE =====

findstr /C:"HTTP/" "%TEMP%\gh_user_test.txt" >nul
if errorlevel 1 (
  echo [ERROR] No HTTP status line in /user response. curl blocked?
  exit /b 1
)

REM ---- Now we switch on delayed expansion locally ----
setlocal EnableDelayedExpansion

set "RELEASE_TAG=v%version%"
set "RELEASE_NAME=%version%"
set "BODY_FILE=%TEMP%\changelog_body.json"
set "CHANGELOG_BODY="

echo [INFO] Creating release body file from %CHANGELOG_FILE% ...

for /f "usebackq delims=" %%l in ("%CHANGELOG_FILE%") do (
  set "line=%%l"
  set "line=!line:"=\\\"!"
  set "CHANGELOG_BODY=!CHANGELOG_BODY!!line!\n"
)

if defined CHANGELOG_BODY (
  set "CHANGELOG_BODY=!CHANGELOG_BODY:~0,-2!"
)

> "!BODY_FILE!" (
  echo {
  echo   "tag_name": "!RELEASE_TAG!",
  echo   "name": "!RELEASE_NAME!",
  echo   "body": "!CHANGELOG_BODY!",
  echo   "draft": false,
  echo   "prerelease": false
  echo }
)

echo [DEBUG] ===== BEGIN JSON BODY =====
type "!BODY_FILE!"
echo [DEBUG] ===== END JSON BODY =====

REM ---- LOOK UP RELEASE BY TAG ----
echo [DEBUG] Looking up release tag: !RELEASE_TAG!
curl -s -w "%%{http_code}" -o "%TEMP%\github_release_response.json" -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/%GITHUB_REPO%/releases/tags/!RELEASE_TAG!" > "%TEMP%\github_http_status.txt"
set /p HTTP_STATUS=<"%TEMP%\github_http_status.txt"
echo [DEBUG] Release tag lookup HTTP: !HTTP_STATUS!

set "RELEASE_ID="

if "!HTTP_STATUS!"=="200" goto HAVE_RELEASE
goto CREATE_RELEASE

:HAVE_RELEASE
for /f "tokens=2 delims=:," %%i in ('findstr /C:"\"id\"" "%TEMP%\github_release_response.json"') do (
  if not defined RELEASE_ID set "RELEASE_ID=%%i"
)
set "RELEASE_ID=!RELEASE_ID: =!"
set "RELEASE_ID=!RELEASE_ID:,=!"
echo [INFO] Release exists. Updating body. ID=!RELEASE_ID!

curl -s -X PATCH -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" --data-binary "@!BODY_FILE!" "https://api.github.com/repos/%GITHUB_REPO%/releases/!RELEASE_ID!" > "%TEMP%\github_patch_response.json"
echo [DEBUG] PATCH response:
type "%TEMP%\github_patch_response.json"
goto UPLOAD_ASSET

:CREATE_RELEASE
echo [INFO] Creating new release...
curl -s -X POST -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" -H "Content-Type: application/json" --data-binary "@!BODY_FILE!" "https://api.github.com/repos/%GITHUB_REPO%/releases" > "%TEMP%\github_release_response.json"

echo [DEBUG] POST response:
type "%TEMP%\github_release_response.json"

for /f "tokens=2 delims=:," %%i in ('findstr /C:"\"id\"" "%TEMP%\github_release_response.json"') do (
  if not defined RELEASE_ID set "RELEASE_ID=%%i"
)
set "RELEASE_ID=!RELEASE_ID: =!"
set "RELEASE_ID=!RELEASE_ID:,=!"

if not defined RELEASE_ID (
  echo [ERROR] Could not determine RELEASE_ID.
  echo [DEBUG] github_release_response.json:
  type "%TEMP%\github_release_response.json"
  endlocal
  exit /b 1
)

:UPLOAD_ASSET
echo [OK] Using Release ID: !RELEASE_ID!
echo [INFO] Uploading asset: %ZIP_NAME%

REM ---- DELETE EXISTING ASSET WITH SAME NAME ----
echo [INFO] Checking for existing asset named %ZIP_NAME% to replace...

curl -s -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" ^
  "https://api.github.com/repos/%GITHUB_REPO%/releases/!RELEASE_ID!/assets" > "%TEMP%\github_assets.json"

for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command ^
  "$a = Get-Content '%TEMP%\github_assets.json' -Raw | ConvertFrom-Json; " ^
  "$m = $a | Where-Object { $_.name -eq '%ZIP_NAME%' } | Select-Object -First 1; " ^
  "if ($m) { $m.id }"`) do set "ASSET_ID=%%A"

if defined ASSET_ID (
  echo [INFO] Deleting existing asset id=!ASSET_ID!
  curl -s -X DELETE -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" ^
    "https://api.github.com/repos/%GITHUB_REPO%/releases/assets/!ASSET_ID!" >nul
) else (
  echo [INFO] No existing asset to delete.
)


curl -s -X POST -H "Authorization: token %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" -H "Content-Type: application/zip" --data-binary "@%ZIP_FILE%" "https://uploads.github.com/repos/%GITHUB_REPO%/releases/!RELEASE_ID!/assets?name=%ZIP_NAME%" > "%TEMP%\github_upload_response.json"

echo [DEBUG] Upload response:
type "%TEMP%\github_upload_response.json"

endlocal
exit /b 0



REM =====================================================
REM MAIN
REM =====================================================
:MAIN

REM PATH SETUP
SET "SCRIPT_DIR=%~dp0"
IF "%SCRIPT_DIR:~-1%"=="\" SET "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM CENTRAL SCRIPTS DIR
IF NOT DEFINED DEPLOY_SCRIPTS_DIR SET "DEPLOY_SCRIPTS_DIR=C:\Ignore By Avast\0. PATHED Items\Themes\deployscripts"

REM LOAD CONFIG
SET "CONFIG_FILE=%SCRIPT_DIR%\deploy-theme.cfg"
IF NOT EXIST "%CONFIG_FILE%" (
  echo [ERROR] Config file not found: %CONFIG_FILE%
  pause & exit /b 1
)

FOR /F "usebackq tokens=1* delims== eol=#" %%A IN ("%CONFIG_FILE%") DO (
  SET "K=%%A"
  IF NOT "!K!"=="" IF NOT "!K:~0,1!"==";" (
    for /f "tokens=* delims= " %%K in ("%%A") do set "KEY=%%K"
    SET "!KEY!=%%B"
  )
)

REM DEFAULTS / CENTRALIZED DEPLOY SCRIPTS
IF NOT DEFINED HEADER_SCRIPT     SET "HEADER_SCRIPT=%DEPLOY_SCRIPTS_DIR%\mytheme_headers.php"
IF NOT DEFINED GENERATOR_SCRIPT  SET "GENERATOR_SCRIPT=%DEPLOY_SCRIPTS_DIR%\generate_theme_index.php"
IF NOT DEFINED TOKEN_FILE        SET "TOKEN_FILE=%DEPLOY_SCRIPTS_DIR%\github_token.txt"

REM LOAD TOKEN (plugin-style)
IF "%GITHUB_TOKEN%"=="" IF EXIST "%TOKEN_FILE%" SET /P GITHUB_TOKEN=<"%TOKEN_FILE%"
call echo [DEBUG] Token starts: %%GITHUB_TOKEN:~0,4%%%%

REM VALIDATION
IF NOT DEFINED THEME_SLUG (
  echo [ERROR] THEME_SLUG is not defined in deploy-theme.cfg
  pause & exit /b 1
)
IF NOT DEFINED GITHUB_REPO (
  echo [ERROR] GITHUB_REPO is not defined in deploy-theme.cfg
  pause & exit /b 1
)

IF NOT DEFINED ZIP_NAME        SET "ZIP_NAME=%THEME_SLUG%.zip"
IF NOT DEFINED CHANGELOG_FILE  SET "CHANGELOG_FILE=changelog.txt"
IF NOT DEFINED STATIC_FILE     SET "STATIC_FILE=static.txt"
IF NOT DEFINED DEPLOY_TARGET   SET "DEPLOY_TARGET=github"

REM PATHS
SET "THEME_DIR=%SCRIPT_DIR%\%THEME_SLUG%"
IF "%THEME_DIR:~-1%"=="\" SET "THEME_DIR=%THEME_DIR:~0,-1%"
SET "STYLE_FILE=%THEME_DIR%\style.css"
SET "REPO_ROOT=%SCRIPT_DIR%"
SET "STATIC_SUBFOLDER=%REPO_ROOT%\uupd"

REM VERIFY FILES
IF NOT EXIST "%STYLE_FILE%" (
  echo [ERROR] style.css not found: %STYLE_FILE%
  pause & exit /b 1
)
IF NOT EXIST "%CHANGELOG_FILE%" (
  echo [ERROR] Changelog file not found: %CHANGELOG_FILE%
  pause & exit /b 1
)
IF NOT EXIST "%STATIC_FILE%" (
  echo [ERROR] Static file not found: %STATIC_FILE%
  pause & exit /b 1
)
IF NOT EXIST "%HEADER_SCRIPT%" (
  echo [ERROR] Header script not found: %HEADER_SCRIPT%
  pause & exit /b 1
)
IF NOT EXIST "%GENERATOR_SCRIPT%" (
  echo [ERROR] Generator script not found: %GENERATOR_SCRIPT%
  pause & exit /b 1
)

REM UPDATE HEADERS
php "%HEADER_SCRIPT%" "%STYLE_FILE%"

REM EXTRACT VERSION
set "version="
for /f "tokens=2* delims=:" %%A in ('findstr /C:"Version:" "%STYLE_FILE%"') do for /f "tokens=* delims= " %%X in ("%%A") do set "version=%%X"
IF "%version%"=="" (
  echo [ERROR] Could not extract Version from %STYLE_FILE%
  pause & exit /b 1
)

REM GENERATE index.json
echo [INFO] Generating index.json for GitHub delivery...
FOR /F "tokens=1,2 delims=/" %%A IN ("%GITHUB_REPO%") DO (
  SET "GITHUB_USER=%%A"
  SET "REPO_NAME=%%B"
)
SET "CDN_PATH=https://raw.githubusercontent.com/%GITHUB_USER%/%REPO_NAME%/main/uupd"
IF NOT EXIST "%STATIC_SUBFOLDER%" mkdir "%STATIC_SUBFOLDER%"

php "%GENERATOR_SCRIPT%" "%STYLE_FILE%" "%CHANGELOG_FILE%" "%STATIC_SUBFOLDER%" "%GITHUB_USER%" "%CDN_PATH%" "%REPO_NAME%" "%REPO_NAME%" "%STATIC_FILE%" "%ZIP_NAME%"

REM ZIP
SET "SEVENZIP=C:\Program Files\7-Zip\7z.exe"
IF NOT EXIST "%SEVENZIP%" (
  echo [ERROR] 7-Zip not found at %SEVENZIP%
  pause & exit /b 1
)

for %%a in ("%THEME_DIR%") do (
  set "PARENT_DIR=%%~dpa"
  set "FOLDER_NAME=%%~nxa"
)
SET "ZIP_FILE=%PARENT_DIR%%ZIP_NAME%"

pushd "%PARENT_DIR%"
"%SEVENZIP%" a -tzip "%ZIP_FILE%" "%FOLDER_NAME%"
popd

echo [OK] Zipped to: %ZIP_FILE%


REM =====================================================
REM GIT COMMIT/PUSH (REPO ROOT) so uupd/ is included
REM =====================================================
echo [INFO] Committing & pushing generated updates to GitHub...

pushd "%REPO_ROOT%" || (echo [ERROR] Failed to enter repo root & exit /b 1)

REM Make sure git exists
where git >nul 2>&1 || (echo [ERROR] git not found on PATH. & popd & exit /b 1)

REM Stage BOTH theme + uupd + any root files you generate
git add -A "%THEME_SLUG%" "uupd" "%CHANGELOG_FILE%" "%STATIC_FILE%" >nul 2>&1

REM Commit only if there are staged changes
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "Version %version% Release" || (echo [ERROR] git commit failed. & popd & exit /b 1)
  git push origin main || (echo [ERROR] git push failed. & popd & exit /b 1)
  echo [OK] Repo commit/push complete.
) else (
  echo [INFO] No repo changes to commit.
)

REM Ensure the git tag exists and points at HEAD (this is key)
git tag -f "v%version%" || (echo [ERROR] git tag failed. & popd & exit /b 1)
git push origin "v%version%" --force || (echo [ERROR] pushing tag failed. & popd & exit /b 1)

popd


REM DEPLOY
IF /I "%DEPLOY_TARGET%"=="github" (
  call :DEPLOY_GITHUB
  if errorlevel 1 (
    echo [ERROR] GitHub deploy failed.
    pause & exit /b 1
  )
)

echo.
echo [OK] Deployment complete: %DEPLOY_TARGET%
pause
exit /b 0
