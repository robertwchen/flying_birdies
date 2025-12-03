@echo off
echo Setting up Git repository...

REM Initialize git if not already done
if not exist .git (
    git init
    echo Git initialized
) else (
    echo Git already initialized
)

REM Add remote
git remote remove origin 2>nul
git remote add origin https://github.com/robertwchen/flying_birdies.git
echo Remote added

REM Add all files
git add .
echo Files staged

REM Commit
git commit -m "feat: Add enhanced graphing with fl_chart - Tasks 1-4 complete"
echo Committed

REM Push to main branch
git branch -M main
git push -u origin main
echo Pushed to GitHub

echo Done!
pause
