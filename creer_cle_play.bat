@echo off
chcp 65001 >nul
setlocal EnableExtensions
rem Cheveche : cree UNE SEULE FOIS la cle d'importation Google Play, puis prepare le texte a coller dans
rem les secrets GitHub (ANDROID_KEYSTORE_BASE64). La cle reste sur ce PC, dans Documents\Cheveche-cle-Play :
rem elle ne va jamais dans le depot.
set "DOSSIER=%USERPROFILE%\Documents\Cheveche-cle-Play"
set "CLE=%DOSSIER%\cheveche-upload.jks"
set "TEXTE=%DOSSIER%\cle_pour_github.txt"
echo.
echo ===== Cheveche : cle Google Play =====
echo.
if exist "%CLE%" (
  echo Une cle existe deja : %CLE%
  echo On la garde telle quelle. Surtout, ne la recreez pas.
  goto texte
)

rem Java fournit l'outil keytool, qui fabrique la cle.
set "KEYTOOL="
for %%k in (keytool.exe) do if not "%%~$PATH:k"=="" set "KEYTOOL=%%~$PATH:k"
if not defined KEYTOOL for /d %%d in ("%ProgramFiles%\Eclipse Adoptium\*" "%ProgramFiles%\Java\*" "%ProgramFiles%\Microsoft\jdk-*" "%ProgramFiles%\Android\Android Studio\jbr") do if exist "%%~d\bin\keytool.exe" set "KEYTOOL=%%~d\bin\keytool.exe"
if not defined KEYTOOL (
  echo Il manque Java sur ce PC : c'est lui qui fabrique la cle.
  echo La page de telechargement va s'ouvrir. Prenez le JDK 17 pour Windows, fichier .msi,
  echo installez-le avec les options proposees, puis relancez ce fichier.
  start "" "https://adoptium.net/temurin/releases/?version=17&os=windows&package=jdk"
  pause
  exit /b 1
)

mkdir "%DOSSIER%" 2>nul
echo Choisissez un mot de passe d'au moins 6 caracteres et notez-le bien :
echo il est demande deux fois ici, puis une derniere fois pour GitHub.
echo Rien ne s'affiche pendant que vous tapez, c'est normal.
echo.
"%KEYTOOL%" -genkeypair -keystore "%CLE%" -storetype PKCS12 -alias cheveche -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Jerome Hosdez, O=Cheveche, C=FR"
if not exist "%CLE%" (
  echo.
  echo La cle n'a pas ete creee. Relancez ce fichier pour reessayer.
  pause
  exit /b 1
)

:texte
certutil -f -encodehex "%CLE%" "%TEXTE%" 0x40000001 >nul
if not exist "%TEXTE%" (
  echo Impossible de preparer le texte pour GitHub.
  pause
  exit /b 1
)
clip < "%TEXTE%"
echo.
echo C'est pret. Le texte de la cle est copie, il n'y a plus qu'a le coller dans GitHub :
echo.
echo  1. La page des secrets du depot va s'ouvrir. Connectez-vous si besoin.
echo  2. Name : ANDROID_KEYSTORE_BASE64
echo     Secret : collez avec Ctrl+V, puis cliquez Add secret.
echo  3. Cliquez New repository secret.
echo     Name : ANDROID_KEYSTORE_PASSWORD
echo     Secret : le mot de passe choisi, puis Add secret.
echo.
echo Gardez une copie du dossier %DOSSIER%
echo et de votre mot de passe, sur une cle USB ou un espace en ligne personnel :
echo sans eux, plus de mise a jour possible sans passer par le support de Google.
echo.
start "" "https://github.com/grosjeje3123/Cheveche-/settings/secrets/actions/new"
start "" explorer "%DOSSIER%"
pause
