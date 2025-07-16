# Initialize-GitRepository.ps1
# Script to initialize and prepare the repository for GitHub upload

Write-Host "=== GSelector Marvin Monitoring - GitHub Repository Setup ===" -ForegroundColor Cyan

# Check if git is installed
try {
    $gitVersion = git --version
    Write-Host "OK: Git detected: $gitVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Git not found. Please install Git first." -ForegroundColor Red
    exit 1
}

# Initialize git repository
Write-Host "`nInitializing Git repository..." -ForegroundColor Yellow
git init

# Add all files
Write-Host "Adding files to repository..." -ForegroundColor Yellow
git add .

# Create initial commit with simple message
Write-Host "Creating initial commit..." -ForegroundColor Yellow
git commit -m "Initial commit: GSelector Marvin monitoring and recovery solution"

Write-Host "`nRepository initialized successfully!" -ForegroundColor Green

Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
Write-Host "1. Create a new repository on GitHub named: gselector-marvin-monitoring"
Write-Host "2. Add the remote origin:"
Write-Host "   git remote add origin https://github.com/yourusername/gselector-marvin-monitoring.git"
Write-Host "3. Push to GitHub:"
Write-Host "   git branch -M main"
Write-Host "   git push -u origin main"

Write-Host "`n=== Repository Structure ===" -ForegroundColor Cyan
Write-Host "scripts/           - Production PowerShell scripts"
Write-Host "documentation/     - Technical documentation"
Write-Host "tests/             - Test scripts and development versions"
Write-Host "README.md          - Project overview and quick start"
Write-Host "LICENSE            - MIT license"
Write-Host ".gitignore         - Git exclusions"

Write-Host "`n=== Suggested GitHub Repository Settings ===" -ForegroundColor Cyan
Write-Host "Repository Name: gselector-marvin-monitoring"
Write-Host "Description: Automated monitoring and recovery solution for GSelector Marvin service deadlocks"
Write-Host "Topics: powershell, monitoring, gselector, automation, broadcast, iis, deadlock-recovery"
Write-Host "Visibility: Private (recommend starting private, then make public if needed)"

Write-Host "`n=== File Summary ===" -ForegroundColor Yellow
$scriptCount = 0
$testCount = 0
$docCount = 0

if (Test-Path "scripts") {
    $scriptCount = (Get-ChildItem -Path "scripts" -Filter "*.ps1" | Measure-Object).Count
}
if (Test-Path "tests") {
    $testCount = (Get-ChildItem -Path "tests" -Filter "*.ps1" | Measure-Object).Count
}
if (Test-Path "documentation") {
    $docCount = (Get-ChildItem -Path "documentation" -Filter "*.md" | Measure-Object).Count
}

Write-Host "Production Scripts: $scriptCount"
Write-Host "Test Scripts: $testCount"
Write-Host "Documentation Files: $docCount"

Write-Host "`nRepository is ready for GitHub upload!" -ForegroundColor Green
