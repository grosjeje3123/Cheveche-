@echo off
chcp 65001 >nul
set PYTHONIOENCODING=utf-8
cd /d "%~dp0"
echo.
echo ===== Cheveche : ajout des images =====
echo.
if not exist images_choisies.txt (
  echo Il manque le fichier images_choisies.txt, a cote de ce fichier.
  echo 1. Ouvrez candidats_images.html et cliquez les images que vous voulez.
  echo 2. Copiez le texte du bas de la page.
  echo 3. Collez-le dans un fichier texte nomme images_choisies.txt, dans ce dossier.
  echo.
  pause
  exit /b 1
)
set PY=
where py >nul 2>nul && set PY=py
if "%PY%"=="" (
  where python >nul 2>nul && set PY=python
)
if "%PY%"=="" (
  echo Python n'est pas installe sur cet ordinateur.
  echo Installez-le depuis https://www.python.org/downloads/ en cochant la case
  echo "Add Python to PATH", puis relancez ce fichier.
  echo.
  pause
  exit /b 1
)
for %%P in (data\packs\*.json) do (
  echo.
  echo ----- %%~nP -----
  %PY% tools\commons_image.py lot %%P images_choisies.txt --yes
)
echo.
echo Termine. Les images sont dans assets\images\^<nom du pack^>. Vous pouvez fermer cette fenetre.
echo.
pause
