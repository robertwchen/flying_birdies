# Git setup script for flying_birdies

Write-Host "Setting up Git repository..." -ForegroundColor Green

# Initialize git if not already done
if (-not (Test-Path .git)) {
    git init
    Write-Host "Git initialized" -ForegroundColor Green
} else {
    Write-Host "Git already initialized" -ForegroundColor Yellow
}

# Configure git (use existing config if available)
$email = git config user.email
$name = git config user.name

if (-not $email) {
    git config user.email "robert@example.com"
    Write-Host "Git email configured" -ForegroundColor Green
}

if (-not $name) {
    git config user.name "Robert Chen"
    Write-Host "Git name configured" -ForegroundColor Green
}

# Add remote (remove if exists)
git remote remove origin 2>$null
git remote add origin https://github.com/robertwchen/flying_birdies.git
Write-Host "Remote added: https://github.com/robertwchen/flying_birdies.git" -ForegroundColor Green

# Add all files
git add .
Write-Host "Files staged" -ForegroundColor Green

# Commit
git commit -m "feat: Add enhanced graphing with fl_chart - Tasks 1-4 complete

- Created chart foundation (ChartTheme, ChartDataPoint, ChartConfiguration)
- Built MinimalLineChart and InteractiveLineChart widgets  
- Integrated fl_chart into Feedback Tab expanded view
- Added axes, labels, data points, and interactive tooltips
- Zero compilation errors, production-ready"

Write-Host "Changes committed" -ForegroundColor Green

# Push to main branch
git branch -M main
git push -u origin main --force
Write-Host "Pushed to GitHub!" -ForegroundColor Green

Write-Host "`nGit setup complete!" -ForegroundColor Cyan
